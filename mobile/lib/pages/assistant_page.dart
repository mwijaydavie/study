import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/personal_yellow_theme.dart';
import '../coach/assistant_preferences.dart';
import '../coach/desk_answers.dart';
import '../design.dart';
import '../study_data.dart';
import '../workspace.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({
    super.key,
    required this.data,
    required this.workspace,
    required this.now,
    required this.openSettings,
    required this.openSchedule,
    required this.openFinance,
    required this.openCoach,
    this.initialQuery = '',
  });
  final StudyData data;
  final Workspace workspace;
  final DateTime Function() now;
  final VoidCallback openSettings, openSchedule, openFinance;
  final ValueChanged<String?> openCoach;
  final String initialQuery;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  late final _input = TextEditingController(text: widget.initialQuery);
  late var _query = widget.initialQuery.trim();
  String? _pinStatus;

  void _run(String query) {
    FocusScope.of(context).unfocus();
    _input.text = query;
    setState(() {
      _query = query.trim();
      _pinStatus = null;
    });
  }

  Future<void> _pin() async {
    final captured = _query;
    final result = await widget.workspace.assistant.pin(captured);
    if (!mounted || _query != captured) return;
    setState(
      () => _pinStatus = switch (result) {
        PinResult.saved => 'Pinned on Home.',
        PinResult.sessionOnly =>
          'Pinned for this visit only; local storage is unavailable.',
        PinResult.off => 'Turn on note memory in AI Settings first.',
        PinResult.invalid =>
          'Use a note between 1 and ${AssistantPreferences.noteLimit} characters.',
        PinResult.duplicate => 'This note is already pinned.',
        PinResult.full =>
          'Home already has ${AssistantPreferences.maxPins} pins. Unpin one before saving another.',
      },
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = widget.workspace.assistant;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal AI'),
        backgroundColor: PersonalAppColors.canvasWhite,
      ),
      body: AmbientSolarBackdrop(
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: Listenable.merge([
              prefs,
              widget.workspace.studyJournal,
            ]),
            builder: (context, _) {
              final now = widget.now();
              final intent = deskIntent(_query);
              final answer = answerOnDevice(
                intent: intent,
                data: widget.data,
                journal: widget.workspace.studyJournal,
                now: now,
                use24Hour: widget.workspace.use24Hour,
                tone: prefs.tone,
              );
              return DeskPage(
                clock: CampusClock.at(now),
                children: [
                  const DeskHero(
                    title: 'Ask your desk',
                    caption: 'OFFLINE ASSISTANT',
                    subtitle:
                        'Check your classes, review your study log, or capture a private note. No online model is connected.',
                    meta: 'On this device · EAT',
                    icon: Icons.auto_awesome_rounded,
                  ),
                  const SizedBox(height: 12),
                  SolarGlass(
                    radius: 18,
                    padding: const EdgeInsets.all(13),
                    blur: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const Key('assistant-input'),
                          controller: _input,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              AssistantPreferences.noteLimit,
                            ),
                          ],
                          textInputAction: TextInputAction.go,
                          onSubmitted: _run,
                          decoration: InputDecoration(
                            labelText: 'Ask or write a note',
                            filled: true,
                            fillColor: DeskColors.white,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              key: const Key('assistant-send'),
                              tooltip: 'Run on device',
                              onPressed: () => _run(_input.text),
                              icon: const Icon(Icons.arrow_forward_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 5,
                          runSpacing: 3,
                          children: [
                            for (final query in [
                              'Leo',
                              'Kesho',
                              'Next class',
                              'Study log',
                              'FN200',
                              'Risk and return',
                            ])
                              ActionChip(
                                label: Text(query),
                                onPressed: () => _run(query),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_query.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DeskCard(
                      key: const Key('assistant-answer'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            header: true,
                            liveRegion: true,
                            child: Text(
                              answer.title,
                              style: deskType(20, weight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            answer.detail,
                            style: deskType(
                              13,
                              height: 1.5,
                              color: DeskColors.muted,
                            ),
                          ),
                          if (intent == DeskIntent.unknown) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Your note',
                              style: deskType(11, color: DeskColors.muted),
                            ),
                            Text(_query, style: deskType(13, height: 1.4)),
                          ],
                          for (final line in answer.lines) ...[
                            const SizedBox(height: 7),
                            Text(line, style: deskType(13, height: 1.4)),
                          ],
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (intent == DeskIntent.today ||
                                  intent == DeskIntent.tomorrow ||
                                  intent == DeskIntent.nextClass)
                                FilledButton.tonal(
                                  onPressed: widget.openSchedule,
                                  child: const Text('Open timetable'),
                                ),
                              if (intent == DeskIntent.studyLog ||
                                  intent == DeskIntent.finance ||
                                  intent == DeskIntent.risk)
                                FilledButton.tonal(
                                  onPressed: () => widget.openCoach(
                                    intent == DeskIntent.risk
                                        ? 'risk-return'
                                        : null,
                                  ),
                                  child: const Text('Open Study Coach'),
                                ),
                              if (intent == DeskIntent.finance ||
                                  intent == DeskIntent.risk)
                                TextButton(
                                  onPressed: widget.openFinance,
                                  child: const Text('Open FN200 guides'),
                                ),
                              if (intent == DeskIntent.unknown && prefs.memory)
                                FilledButton.tonal(
                                  key: const Key('pin-capture'),
                                  onPressed: _pin,
                                  child: const Text('Pin note'),
                                ),
                              if (intent == DeskIntent.unknown && !prefs.memory)
                                TextButton(
                                  onPressed: widget.openSettings,
                                  child: const Text(
                                    'Enable pins in AI Settings',
                                  ),
                                ),
                            ],
                          ),
                          if (_pinStatus case final status?) ...[
                            const SizedBox(height: 4),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                status,
                                style: deskType(12, height: 1.4),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 9),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: widget.openSettings,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('AI Settings'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class AiSettingsPage extends StatelessWidget {
  const AiSettingsPage({
    super.key,
    required this.preferences,
    required this.now,
  });
  final AssistantPreferences preferences;
  final DateTime Function() now;

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Clear pinned notes?'),
        content: const Text(
          'This removes the notes shown on Home. Study history, files and your checklist are not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Clear notes'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) await preferences.clearPins();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('AI Settings'),
      backgroundColor: PersonalAppColors.canvasWhite,
    ),
    body: AmbientSolarBackdrop(
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: preferences,
          builder: (context, _) => DeskPage(
            clock: CampusClock.at(now()),
            children: [
              const DeskHero(
                title: 'Your assistant',
                caption: 'LOCAL PREFERENCES',
                subtitle:
                    'Control the tone and what you choose to keep. Your notes never leave this phone through StudyDesk.',
                meta: 'No account or API key',
                icon: Icons.tune_rounded,
              ),
              const SizedBox(height: 12),
              const DeskCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle('Model', 'Offline Study Coach'),
                    SizedBox(height: 7),
                    Text(
                      'Uses bundled timetable and study materials. No cloud model or provider is connected.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              DeskCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      'Tone',
                      'Applies to supported offline replies, not the spoken welcome.',
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      runSpacing: 4,
                      children: [
                        for (final tone in AssistantTone.values)
                          ChoiceChip(
                            label: Text(
                              tone == AssistantTone.friendly
                                  ? 'Friendly'
                                  : 'Brief',
                            ),
                            selected: preferences.tone == tone,
                            onSelected: (selected) {
                              if (selected) preferences.setTone(tone);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              DeskCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      key: const Key('assistant-memory'),
                      title: const Text('Note memory'),
                      subtitle: const Text(
                        'Allow manual pins, not conversation history. Turning this off stops new pins; existing notes stay until removed.',
                      ),
                      value: preferences.memory,
                      onChanged: preferences.setMemory,
                    ),
                    if (preferences.pins.isNotEmpty || preferences.unreadable)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          child: TextButton(
                            onPressed: () => _clear(context),
                            child: const Text('Clear pinned notes'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!preferences.canSave) ...[
                const SizedBox(height: 8),
                DeskCard(
                  child: Text(
                    preferences.unreadable
                        ? 'Saved notes could not be read. Changes are temporary until you clear the saved notes.'
                        : 'Device storage is unavailable. Changes apply to this visit only.',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
