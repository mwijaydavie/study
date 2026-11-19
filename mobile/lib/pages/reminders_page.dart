import 'package:flutter/material.dart';

import '../design.dart';
import '../reminders/reminder_plan.dart';
import '../reminders/reminders.dart';
import '../study_data.dart';

void _feedback(BuildContext context, String? message) {
  if (message == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> editClassReminder(
  BuildContext context, {
  required ReminderController reminders,
  required Session session,
  required bool use24Hour,
  ReminderRequest? existing,
}) async {
  if (reminders.busy) return;
  final now = reminders.now();
  final dates = reminders.plan
      .choices(session, now)
      .where(
        (choice) =>
            existing == null ||
            campusDayKey(choice.campusDay) == existing.dayKey,
      )
      .toList(growable: false);
  if (dates.isEmpty) {
    _feedback(
      context,
      'There is no future reminder time for that class date. You can still remove an existing reminder.',
    );
    return;
  }
  final choice = await showDialog<({ClassOccurrence occurrence, int lead})>(
    context: context,
    builder: (_) => _ReminderEditor(
      reminders: reminders,
      choices: dates,
      now: now,
      use24Hour: use24Hour,
      preferredLead: existing?.lead ?? 15,
    ),
  );
  if (choice == null || !context.mounted) return;
  final message = await reminders.setClassReminder(
    choice.occurrence,
    choice.lead,
  );
  if (context.mounted) _feedback(context, message);
}

class _ReminderEditor extends StatefulWidget {
  const _ReminderEditor({
    required this.reminders,
    required this.choices,
    required this.now,
    required this.use24Hour,
    required this.preferredLead,
  });
  final ReminderController reminders;
  final List<ClassOccurrence> choices;
  final DateTime now;
  final bool use24Hour;
  final int preferredLead;

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<_ReminderEditor> {
  late ClassOccurrence _choice = widget.choices.first;
  late int _lead = _validLead(widget.preferredLead);

  int _validLead(int preferred) {
    final available = _choice.availableLeads(widget.now);
    return available.contains(preferred) ? preferred : available.first;
  }

  @override
  Widget build(BuildContext context) {
    final session = _choice.session;
    final start = formatTime(session.start, use24Hour: widget.use24Hour);
    return AlertDialog(
      scrollable: true,
      title: const Text('Set class reminder'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${session.code} · ${widget.reminders.plan.data.titleFor(session)}',
            style: deskType(14, weight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text('${session.kindLabel} · $start EAT · ${session.venue}'),
          const SizedBox(height: 14),
          const Text('Class date (EAT)'),
          DropdownButton<ClassOccurrence>(
            key: const Key('reminder-date'),
            isExpanded: true,
            value: _choice,
            items: [
              for (final date in widget.choices)
                DropdownMenuItem(
                  value: date,
                  child: Text(campusDayLabel(date.campusDay)),
                ),
            ],
            onChanged: (date) {
              if (date != null)
                setState(() {
                  _choice = date;
                  _lead = _validLead(_lead);
                });
            },
          ),
          const SizedBox(height: 8),
          const Text('Notify before class'),
          DropdownButton<int>(
            key: const Key('reminder-lead'),
            isExpanded: true,
            value: _lead,
            items: [
              for (final lead in _choice.availableLeads(widget.now))
                DropdownMenuItem(value: lead, child: Text('$lead minutes')),
            ],
            onChanged: (lead) {
              if (lead != null) setState(() => _lead = lead);
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Target: ${campusStamp(_choice.target(_lead), use24Hour: widget.use24Hour)}',
            style: deskType(12, color: blue.ink, weight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'This timetable is a revised draft. Confirm the class date with UAUT before saving. This sets one notification, not a weekly repeat or an exact alarm.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-class-reminder'),
          onPressed: () =>
              Navigator.of(context).pop((occurrence: _choice, lead: _lead)),
          child: const Text('Confirm date & set'),
        ),
      ],
    );
  }
}

class ClassRemindersPage extends StatelessWidget {
  const ClassRemindersPage({
    super.key,
    required this.reminders,
    required this.use24Hour,
  });
  final ReminderController reminders;
  final bool use24Hour;

  Future<void> _chooseClass(BuildContext context) async {
    final classes = reminders.plan.classes.toList(growable: false);
    final session = await showModalBottomSheet<Session>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * .68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  'Pick a class',
                  style: deskType(20, weight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: classes.length,
                  itemBuilder: (_, index) {
                    final item = classes[index];
                    return ListTile(
                      title: Text(
                        '${item.code} · ${reminders.plan.data.titleFor(item)}',
                      ),
                      subtitle: Text(
                        '${dayName(item.day)} · ${formatTime(item.start, use24Hour: use24Hour)} EAT · ${item.kindLabel}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(sheet).pop(item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (session == null || !context.mounted) return;
    await editClassReminder(
      context,
      reminders: reminders,
      session: session,
      use24Hour: use24Hour,
    );
  }

  Future<void> _run(BuildContext context, Future<String?> operation) async {
    final message = await operation;
    if (context.mounted) _feedback(context, message);
  }

  Future<void> _removeAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Turn off class and test reminders?'),
        content: const Text(
          'This cancels pending class and test notifications. Campus event notifications, your timetable and Android settings are unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep reminders'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Turn off all'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted)
      await _run(context, reminders.removeAll());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: reminders,
    builder: (context, _) {
      final blocked =
          reminders.access == NotificationAccess.denied ||
          reminders.access == NotificationAccess.blocked;
      final unavailable = reminders.access == NotificationAccess.unavailable;
      final waiting = reminders.access == NotificationAccess.checking;
      final ready = !reminders.busy && !unavailable && !waiting;
      final now = reminders.now();
      return Scaffold(
        appBar: AppBar(
          title: const Text('Class reminders'),
          actions: [
            IconButton(
              tooltip: 'Refresh reminder status',
              onPressed: reminders.busy
                  ? null
                  : () => _run(context, reminders.refresh()),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: DeskPage(
          clock: CampusClock.at(now),
          children: [
            DeskHero(
              title: 'Class reminders',
              caption: 'ANDROID · OFFLINE',
              subtitle: 'Pick a class date and when to be notified.',
              meta: 'East Africa Time',
              icon: Icons.notifications_outlined,
              background: violet.surface,
              accent: violet.ink,
            ),
            const SizedBox(height: 12),
            DeskCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminders.statusLabel,
                    style: deskType(14, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    blocked
                        ? 'Allow StudyDesk notifications in Android. Your timetable stays available either way.'
                        : unavailable
                        ? 'Refresh to reconnect to the Android reminder service.'
                        : 'No reminders are added automatically. Confirm a class date from the current draft within the next 14 days.',
                    style: deskType(12, color: DeskColors.muted, height: 1.45),
                  ),
                  if (reminders.busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: LinearProgressIndicator(
                        semanticsLabel: 'Updating reminders',
                      ),
                    ),
                  if (blocked)
                    TextButton.icon(
                      onPressed: ready
                          ? () => _run(context, reminders.openSettings())
                          : null,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Open Android settings'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: ready && !blocked ? () => _chooseClass(context) : null,
              icon: const Icon(Icons.add),
              label: const Text('Add a class reminder'),
            ),
            const SizedBox(height: 14),
            const SectionTitle(
              'Pending reminders',
              'Targets shown in EAT. Android decides delivery time.',
            ),
            const SizedBox(height: 8),
            if (reminders.removedChangedClasses)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: MetaLabel(
                  Icons.info_outline,
                  'Some class reminders no longer matched the timetable and were removed. Confirm the dates to set them again.',
                ),
              ),
            if (unavailable)
              const DeskCard(child: Text('Could not check pending reminders.'))
            else if (reminders.pending.isEmpty)
              const DeskCard(child: Text('Nothing scheduled yet.'))
            else ...[
              for (final item in reminders.pending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PendingCard(
                    item: item,
                    use24Hour: use24Hour,
                    now: now,
                    waitingForPermission: blocked,
                    onEdit: ready && !blocked && !item.isTest
                        ? () {
                            final session = reminders.plan
                                .occurrence(item.sessionId, item.dayKey)
                                ?.session;
                            if (session != null)
                              editClassReminder(
                                context,
                                reminders: reminders,
                                session: session,
                                use24Hour: use24Hour,
                                existing: item,
                              );
                          }
                        : null,
                    onRemove: ready
                        ? () => _run(context, reminders.remove(item.key))
                        : null,
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: ready ? () => _removeAll(context) : null,
                  child: const Text('Turn off class & test reminders'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            DeskCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test on this phone',
                    style: deskType(14, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Send a normal notification now, or set an approximate one-minute test before locking the screen.',
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      TextButton(
                        onPressed: ready && !blocked
                            ? () => _run(
                                context,
                                reminders.sendTest(delayed: false),
                              )
                            : null,
                        child: const Text('Send test now'),
                      ),
                      TextButton(
                        onPressed: ready && !blocked
                            ? () => _run(
                                context,
                                reminders.sendTest(delayed: true),
                              )
                            : null,
                        child: const Text('Schedule lock-screen test'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            DeskCard(
              color: gold.surface,
              border: gold.surface,
              child: Text(
                'These are ordinary notifications, not exact alarms. Battery settings, Do Not Disturb, force stop or reboot can affect delivery. A class notification is dropped if its start time has passed.',
                style: deskType(11.5, color: gold.ink, height: 1.45),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.item,
    required this.use24Hour,
    required this.now,
    required this.waitingForPermission,
    this.onEdit,
    this.onRemove,
  });
  final ReminderRequest item;
  final bool use24Hour;
  final DateTime now;
  final bool waitingForPermission;
  final VoidCallback? onEdit, onRemove;

  @override
  Widget build(BuildContext context) => DeskCard(
    key: ValueKey(item.key),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.title, style: deskType(14, weight: FontWeight.w800)),
        const SizedBox(height: 4),
        if (!item.isTest)
          Text(
            'Class: ${campusStamp(item.expires, use24Hour: use24Hour)}',
            style: deskType(12),
          ),
        Text(
          'Target: ${campusStamp(item.target, use24Hour: use24Hour)}${item.lead == null ? '' : ' · ${item.lead} min before'}',
          style: deskType(11.5, color: DeskColors.muted),
        ),
        if (waitingForPermission || !item.target.isAfter(now))
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              waitingForPermission
                  ? 'Not armed · waiting for permission'
                  : 'Target passed · delivery not confirmed',
              style: deskType(11, color: gold.ink),
            ),
          ),
        Wrap(
          spacing: 6,
          children: [
            if (onEdit != null)
              TextButton(onPressed: onEdit, child: const Text('Edit time')),
            TextButton(onPressed: onRemove, child: const Text('Remove')),
          ],
        ),
      ],
    ),
  );
}
