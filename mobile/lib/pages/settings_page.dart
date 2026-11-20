import 'package:flutter/material.dart';

import '../design.dart';
import '../reminders/reminders.dart';
import '../study_data.dart';
import '../ui/welcome_voice.dart';
import '../workspace.dart';
import 'campus_events_page.dart';
import 'reminders_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.data,
    required this.clock,
    required this.workspace,
    required this.openAiSettings,
    this.reminders,
    this.welcomeVoice,
  });
  final StudyData data;
  final CampusClock clock;
  final Workspace workspace;
  final VoidCallback openAiSettings;
  final ReminderController? reminders;
  final WelcomeVoice? welcomeVoice;

  Future<void> _clearWeek(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Clear this week’s checklist?'),
        content: const Text(
          'Completed study blocks for the current EAT week will be unchecked on this device. The timetable and settings will not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Clear checklist'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted)
      await workspace.clearWeek(clock.weekKey);
  }

  @override
  Widget build(BuildContext context) => DeskPage(
    clock: clock,
    children: [
      DeskHero(
        title: 'Settings',
        caption: 'MWIJAY’S WORKSPACE',
        subtitle: 'Make StudyDesk work the way you like.',
        meta: '${data.cohort} · Personal app',
        icon: Icons.settings_outlined,
      ),
      const SizedBox(height: 12),
      DeskCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          key: const Key('open-ai-settings'),
          leading: const DeskGlyph(Icons.auto_awesome_rounded, tones: gold),
          title: const Text('AI Settings'),
          subtitle: const Text('Offline model, tone, and note memory'),
          trailing: const Icon(Icons.chevron_right),
          onTap: openAiSettings,
        ),
      ),
      const SizedBox(height: 16),
      const SectionTitle(
        'Timetable preferences',
        'These settings are only for this device.',
      ),
      const SizedBox(height: 9),
      DeskCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SwitchListTile(
              key: const Key('use-24-hour'),
              title: Text(
                '24-hour time',
                style: deskType(13, weight: FontWeight.w800),
              ),
              subtitle: Text(
                workspace.use24Hour
                    ? 'Example: 14:00 EAT'
                    : 'Example: 2:00 PM EAT',
                style: deskType(11, color: DeskColors.muted),
              ),
              value: workspace.use24Hour,
              onChanged: workspace.setTimeFormat,
            ),
            const Divider(height: 1, indent: 14, endIndent: 14),
            SwitchListTile(
              key: const Key('default-week-view'),
              title: Text(
                'Open Week view by default',
                style: deskType(13, weight: FontWeight.w800),
              ),
              subtitle: Text(
                workspace.defaultView == ScheduleView.week
                    ? 'Open Timetable with the full teaching week'
                    : 'Open Timetable with today’s classes',
                style: deskType(11, color: DeskColors.muted),
              ),
              value: workspace.defaultView == ScheduleView.week,
              onChanged: (week) => workspace.setDefaultView(
                week ? ScheduleView.week : ScheduleView.day,
              ),
            ),
          ],
        ),
      ),
      if (welcomeVoice case final voice?) ...[
        const SizedBox(height: 13),
        _WelcomeVoiceSetting(voice: voice),
      ],
      if (reminders case final controller?) ...[
        const SizedBox(height: 13),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => DeskCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const Key('class-reminders-settings'),
              leading: const DeskGlyph(
                Icons.notifications_outlined,
                tones: violet,
              ),
              title: Text(
                'Class reminders',
                style: deskType(13, weight: FontWeight.w800),
              ),
              subtitle: Text(
                controller.statusLabel,
                style: deskType(11.5, color: DeskColors.muted, height: 1.45),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                controller.refresh();
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ClassRemindersPage(
                      reminders: controller,
                      use24Hour: workspace.use24Hour,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (controller.campusEvents case final events?) ...[
          const SizedBox(height: 8),
          DeskCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const Key('campus-events-settings'),
              leading: const DeskGlyph(Icons.event_note_outlined, tones: green),
              title: Text(
                'Campus events',
                style: deskType(13, weight: FontWeight.w800),
              ),
              subtitle: Text(
                'Personal dates, reminders and Calendar handoff',
                style: deskType(11.5, color: DeskColors.muted, height: 1.45),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                controller.refresh();
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CampusEventsPage(
                      book: events,
                      reminders: controller,
                      use24Hour: workspace.use24Hour,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
      const SizedBox(height: 13),
      DeskCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              leading: const DeskGlyph(
                Icons.offline_bolt_outlined,
                tones: green,
              ),
              title: Text(
                'Offline & privacy',
                style: deskType(13, weight: FontWeight.w800),
              ),
              subtitle: Text(
                'Classes, guides and files ship with the app. Settings and progress use phone storage. No StudyDesk account or sync; system backup settings may apply.',
                style: deskType(11.5, color: DeskColors.muted, height: 1.45),
              ),
            ),
            const Divider(height: 1, indent: 14, endIndent: 14),
            ListTile(
              leading: const DeskGlyph(Icons.schedule_rounded, tones: blue),
              title: Text(
                'Campus time',
                style: deskType(13, weight: FontWeight.w800),
              ),
              subtitle: Text(
                'Dar es Salaam · EAT (UTC+3). This does not change your phone clock.',
                style: deskType(11.5, color: DeskColors.muted, height: 1.45),
              ),
            ),
            const Divider(height: 1, indent: 14, endIndent: 14),
            ListTile(
              leading: const DeskGlyph(Icons.restart_alt_rounded, tones: peach),
              title: Text(
                'Clear this week’s checklist',
                style: deskType(13, weight: FontWeight.w800),
              ),
              subtitle: Text(
                workspace.doneFor(clock.weekKey).isEmpty
                    ? 'Nothing to clear this week'
                    : 'Uncheck completed study blocks',
                style: deskType(11.5, color: DeskColors.muted),
              ),
              trailing: workspace.doneFor(clock.weekKey).isEmpty
                  ? null
                  : const Icon(Icons.chevron_right),
              enabled: workspace.doneFor(clock.weekKey).isNotEmpty,
              onTap: workspace.doneFor(clock.weekKey).isEmpty
                  ? null
                  : () => _clearWeek(context),
            ),
          ],
        ),
      ),
      if (!workspace.canSave) ...[
        const SizedBox(height: 10),
        DeskCard(
          color: peach.surface,
          border: peach.surface,
          child: MetaLabel(
            Icons.info_outline,
            'Device storage is unavailable. Changes may not survive a restart.',
            color: peach.ink,
          ),
        ),
      ],
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () =>
              showLicensePage(context: context, applicationName: 'StudyDesk'),
          icon: const Icon(Icons.description_outlined, size: 16),
          label: const Text('Open-source licenses'),
        ),
      ),
      const SizedBox(height: 6),
      DeskCard(
        color: const Color(0xfffcf7e9),
        border: const Color(0xffede4cc),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MetaLabel(
              Icons.info_outline,
              'This build · Personal StudyDesk',
              color: gold.ink,
              size: 13,
            ),
            const SizedBox(height: 5),
            Text(
              '${data.termLabel} · revised draft, page ${data.sourcePage}. ${reminders == null ? 'Reminders and Campus events are Android-only in this phase.' : 'Calendar handoff is optional; StudyDesk reads no device calendars.'} Clock alarms are not connected.',
              style: deskType(11.5, color: gold.ink, height: 1.5),
            ),
          ],
        ),
      ),
    ],
  );
}

class _WelcomeVoiceSetting extends StatelessWidget {
  const _WelcomeVoiceSetting({required this.voice});
  final WelcomeVoice voice;

  Future<void> _preview(BuildContext context) async {
    final started = await voice.preview();
    if (started || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'No greeting played. Check silent mode and media volume, or wait for current audio.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => DeskCard(
    padding: EdgeInsets.zero,
    child: ListenableBuilder(
      listenable: voice,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const Key('spoken-welcome'),
            secondary: const DeskGlyph(Icons.volume_up_outlined, tones: gold),
            title: Text(
              'Spoken welcome',
              style: deskType(13, weight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Salamu za Mwijay wakati wa kufungua app. Sauti ziko kwenye simu.',
            ),
            value: voice.enabled,
            onChanged: voice.setEnabled,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 5),
            child: TextButton.icon(
              onPressed: () => _preview(context),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Preview next greeting'),
            ),
          ),
        ],
      ),
    ),
  );
}
