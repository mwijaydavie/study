import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../coach/finance_quiz.dart';
import '../coach/study_journal.dart';
import '../design.dart';
import '../study_data.dart';
import '../ui/desk_motion.dart';
import 'finance_quiz_page.dart';

class StudyCoachPage extends StatefulWidget {
  const StudyCoachPage({
    super.key,
    required this.data,
    required this.journal,
    required this.now,
  });

  final StudyData data;
  final StudyJournal journal;
  final DateTime Function() now;

  @override
  State<StudyCoachPage> createState() => _StudyCoachPageState();
}

class _StudyCoachPageState extends State<StudyCoachPage>
    with WidgetsBindingObserver {
  late String _course = widget.data.courses.containsKey('FN200')
      ? 'FN200'
      : widget.data.courses.keys.first;
  late final Future<FinanceQuizBank> _bank;
  final _minutes = TextEditingController();
  late String _editingDay;
  String? _source;
  String? _error;

  String _dayAt(DateTime at) => campusDayKey(campusDayOf(at));

  @override
  void initState() {
    super.initState();
    _bank = FinanceQuizBank.load(rootBundle);
    _loadEditor(widget.now());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _minutes.dispose();
    super.dispose();
  }

  void _loadEditor(DateTime at) {
    _editingDay = _dayAt(at);
    _minutes.text =
        widget.journal.at(at).minutesByCourse[_course]?.toString() ?? '';
    _error = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = widget.now();
    if (state == AppLifecycleState.resumed && _editingDay != _dayAt(now)) {
      setState(() => _loadEditor(now));
    }
  }

  Future<void> _save() async {
    final now = widget.now();
    if (_editingDay != _dayAt(now)) {
      setState(() {
        _loadEditor(now);
        _error = 'Ni siku mpya ya EAT. Weka dakika za leo.';
      });
      return;
    }
    final value = int.tryParse(_minutes.text);
    if (value == null || value > StudyJournal.maxMinutes) {
      setState(
        () => _error = 'Weka dakika 0–1440. Tumia 0 kuondoa somo la leo.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final code = _course;
    final saved = await widget.journal.setMinutes(now, code, value);
    if (!mounted) return;
    if (!saved) {
      setState(() => _error = 'Jumla ya siku haiwezi kuzidi dakika 1440.');
      return;
    }
    DeskHaptics.confirm();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            widget.journal.canSave
                ? 'Kumbukumbu ya $code imesasishwa.'
                : 'Imesasishwa kwa muda huu; hifadhi ya simu haipatikani.',
          ),
        ),
      );
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Clear study history?'),
        content: const Text(
          'This clears local study minutes and quiz totals, not your weekly checklist or files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await widget.journal.clear();
    if (mounted) setState(() => _loadEditor(widget.now()));
  }

  void _practice(FinanceQuizBank bank) {
    final questions = bank.practice(sourceId: _source);
    if (questions.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FinanceQuizPage(
          questions: questions,
          journal: widget.journal,
          now: widget.now,
        ),
      ),
    );
  }

  Widget _today(StudyDay day) => DeskCard(
    color: violet.surface,
    border: violet.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetaLabel(Icons.today_outlined, 'LEO · EAT', color: violet.ink),
        const SizedBox(height: 6),
        Text(
          'Dakika ${day.totalMinutes}',
          key: const Key('coach-today-minutes'),
          style: deskType(25, weight: FontWeight.w800, color: violet.ink),
        ),
        const SizedBox(height: 5),
        Text(
          day.minutesByCourse.isEmpty
              ? 'Bado hujarekodi somo leo.'
              : day.minutesByCourse.entries
                    .map((entry) => '${entry.key}: ${entry.value}m')
                    .join('  ·  '),
          style: deskType(12.5, color: violet.ink),
        ),
        const Divider(height: 18),
        Text(
          'Quiz leo: ${day.correct} / ${day.answered} sahihi',
          style: deskType(12, color: violet.ink),
        ),
      ],
    ),
  );

  Widget _editor() => DeskCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'Rekodi somo',
          'Weka jumla ya dakika ulizosoma somo hilo leo. 0 huondoa rekodi yake ya leo.',
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const Key('coach-course'),
          value: _course,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Somo',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final entry in widget.data.courses.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(
                  '${entry.key} · ${entry.value.title}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (code) {
            if (code == null || code == _course) return;
            DeskHaptics.selection();
            setState(() {
              _course = code;
              _loadEditor(widget.now());
            });
          },
        ),
        const SizedBox(height: 9),
        TextField(
          key: const Key('coach-minutes'),
          controller: _minutes,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            labelText: 'Dakika za leo',
            hintText: 'Mfano: 25',
            errorText: _error,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 9),
        FilledButton.icon(
          key: const Key('save-coach-study'),
          onPressed: _save,
          icon: const Icon(Icons.check_rounded, size: 20),
          label: const Text('Hifadhi dakika'),
        ),
      ],
    ),
  );

  Widget _quiz() => DeskCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'Tujipime · FN200',
          'Maswali ya offline kutoka PDF mbili. Kila jibu lina maelezo na rejea ya ukurasa.',
        ),
        const SizedBox(height: 9),
        FutureBuilder<FinanceQuizBank>(
          future: _bank,
          builder: (context, snapshot) {
            final bank = snapshot.data;
            if (bank == null) {
              return Text(
                snapshot.hasError
                    ? 'Couldn’t open the quiz pack. Your log and guides are still available.'
                    : 'Inafungua maswali ya offline…',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final entry in [
                      const MapEntry<String?, String>(null, 'PDF zote'),
                      ...bank.sources.values.map(
                        (source) =>
                            MapEntry<String?, String>(source.id, source.title),
                      ),
                    ])
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _source == entry.key,
                        onSelected: (selected) {
                          if (!selected || entry.key == _source) return;
                          DeskHaptics.selection();
                          setState(() => _source = entry.key);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  key: const Key('start-fn200-quiz'),
                  onPressed: () => _practice(bank),
                  icon: const Icon(Icons.quiz_outlined, size: 19),
                  label: const Text('Anza quiz · maswali 5'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 7),
        Text(
          'Soma muhtasari: Materials → FN200. Quiz hii si huduma ya AI mtandaoni.',
          style: deskType(11, color: DeskColors.muted, height: 1.4),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Study Coach')),
    body: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: widget.journal,
        builder: (context, _) {
          final now = widget.now();
          final clock = CampusClock.at(now);
          final recent = widget.journal.recent();
          return DeskPage(
            clock: clock,
            children: [
              DeskHero(
                title: 'Umesoma nini leo?',
                caption: 'MWIJAY · STUDY COACH',
                subtitle:
                    'Rekodi ulichosoma, kisha jaribu swali kutoka kwenye notes zako.',
                meta: '${clock.dateLabel} · EAT · Offline',
                icon: Icons.auto_stories_outlined,
                background: DeskColors.gold,
              ),
              const SizedBox(height: 12),
              _today(widget.journal.at(now)),
              const SizedBox(height: 10),
              _editor(),
              const SizedBox(height: 10),
              _quiz(),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 13),
                const SectionTitle(
                  'Kumbukumbu',
                  'Siku za karibu zenye rekodi · EAT',
                ),
                const SizedBox(height: 7),
                for (final entry in recent) ...[
                  DeskCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campusDayLabel(parseCampusDay(entry.key)!),
                          style: deskType(13, weight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${entry.value.totalMinutes}m · ${entry.value.minutesByCourse.keys.join(', ')}${entry.value.minutesByCourse.isEmpty ? 'Quiz only' : ''} · ${entry.value.correct}/${entry.value.answered} quiz',
                          style: deskType(12, color: DeskColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
              ],
              const SizedBox(height: 10),
              DeskCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MetaLabel(
                      Icons.lock_outline_rounded,
                      'Kwenye simu hii tu',
                      color: green.ink,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Study Coach saves the minutes you enter and quiz totals. It does not monitor your phone or upload your notes.',
                      style: deskType(
                        12,
                        color: DeskColors.muted,
                        height: 1.45,
                      ),
                    ),
                    if (!widget.journal.canSave) ...[
                      const SizedBox(height: 7),
                      Text(
                        widget.journal.unreadable
                            ? 'Stored history is unreadable. New entries are temporary until you clear it.'
                            : 'Local storage is unavailable; this visit is temporary.',
                        style: deskType(12, color: peach.ink),
                      ),
                    ],
                    if (widget.journal.hasHistory)
                      TextButton(
                        onPressed: _clear,
                        child: const Text('Clear study history'),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
