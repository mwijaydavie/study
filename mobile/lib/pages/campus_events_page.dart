import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../campus/campus_calendar.dart';
import '../campus/campus_events.dart';
import '../design.dart';
import '../reminders/reminders.dart';
import '../study_data.dart';
import 'campus_event_editor.dart';

String _eventWhen(CampusEvent event, {required bool use24Hour}) {
  if (event.allDay) {
    final lastDate = event.through;
    return '${campusDayLabel(event.day)}${lastDate == null || lastDate == event.day ? '' : ' – ${campusDayLabel(lastDate)}'} · All day (EAT)';
  }
  final start = campusStamp(event.start, use24Hour: use24Hour);
  final end = event.end;
  if (end == null) return start;
  final endLabel = event.through == event.day
      ? '${clockText(event.endMinute!, use24Hour: use24Hour)} EAT'
      : campusStamp(end, use24Hour: use24Hour);
  return '$start – $endLabel';
}

void _notice(BuildContext context, String? message) {
  if (!context.mounted || message == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _edit(
  BuildContext context,
  ReminderController reminders,
  bool use24Hour, [
  CampusEvent? event,
]) async {
  final result = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => CampusEventEditor(
        reminders: reminders,
        use24Hour: use24Hour,
        event: event,
      ),
    ),
  );
  if (context.mounted) _notice(context, result);
}

class CampusEventsPage extends StatefulWidget {
  const CampusEventsPage({
    super.key,
    required this.book,
    required this.reminders,
    required this.use24Hour,
    this.calendar = const AndroidCampusPlatform(),
  });
  final CampusEventBook book;
  final ReminderController reminders;
  final bool use24Hour;
  final DeviceCalendar calendar;

  @override
  State<CampusEventsPage> createState() => _CampusEventsPageState();
}

class _CampusEventsPageState extends State<CampusEventsPage> {
  bool _past = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.book, widget.reminders]),
    builder: (context, _) {
      final now = widget.reminders.now();
      final items = widget.book.listAt(now, past: _past);
      return Scaffold(
        appBar: AppBar(title: const Text('Campus events')),
        body: SafeArea(
          top: false,
          child: DeskPage(
            clock: CampusClock.at(now),
            children: [
              DeskHero(
                title: 'Campus events',
                caption: 'PERSONAL · OFFLINE',
                subtitle:
                    'Keep your own seminars, exams and deadlines in one place.',
                meta: 'Africa/Dar_es_Salaam',
                icon: Icons.event_note_outlined,
                background: green.surface,
                accent: green.ink,
              ),
              const SizedBox(height: 14),
              if (!widget.book.available)
                const DeskCard(
                  child: Text(
                    'Event storage is unavailable. Reopen StudyDesk to try again. Your timetable is unchanged.',
                  ),
                )
              else ...[
                FilledButton.icon(
                  key: const Key('add-campus-event'),
                  onPressed: () =>
                      _edit(context, widget.reminders, widget.use24Hour),
                  icon: const Icon(Icons.add),
                  label: const Text('Add event'),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('Upcoming & ongoing'),
                      selected: !_past,
                      onSelected: (_) => setState(() => _past = false),
                    ),
                    ChoiceChip(
                      label: const Text('Past'),
                      selected: _past,
                      onSelected: (_) => setState(() => _past = true),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (items.isEmpty)
                  DeskCard(
                    child: Text(
                      _past
                          ? 'No past events saved.'
                          : 'No upcoming events yet. Add a date you want to keep track of.',
                    ),
                  )
                else
                  for (final event in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DeskCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          key: ValueKey(event.id),
                          leading: const DeskGlyph(
                            Icons.event_outlined,
                            tones: green,
                          ),
                          title: Text(
                            event.title,
                            style: deskType(14, weight: FontWeight.w800),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${_eventWhen(event, use24Hour: widget.use24Hour)}\n${event.kind.label} · ${event.status}',
                              style: deskType(
                                11.5,
                                color: DeskColors.muted,
                                height: 1.45,
                              ),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => CampusEventDetail(
                                eventId: event.id,
                                book: widget.book,
                                reminders: widget.reminders,
                                use24Hour: widget.use24Hour,
                                calendar: widget.calendar,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
              const SizedBox(height: 8),
              const MetaLabel(
                Icons.info_outline,
                'These dates are entered by you. This is not an official university feed.',
              ),
            ],
          ),
        ),
      );
    },
  );
}

class CampusEventDetail extends StatelessWidget {
  const CampusEventDetail({
    super.key,
    required this.eventId,
    required this.book,
    required this.reminders,
    required this.use24Hour,
    this.calendar = const AndroidCampusPlatform(),
  });
  final String eventId;
  final CampusEventBook book;
  final ReminderController reminders;
  final bool use24Hour;
  final DeviceCalendar calendar;

  Future<void> _delete(BuildContext context, CampusEvent event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const Text('Delete this event?'),
        content: const Text(
          'This removes the event and its StudyDesk notification. Any separate copy in Calendar will stay there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Delete event'),
          ),
        ],
      ),
    );
    if (confirm != true ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent != true)
      return;
    final result = await reminders.deleteEvent(event.id);
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    _notice(context, result.message);
    if (result.saved) Navigator.of(context).pop();
  }

  Future<void> _handoff(
    BuildContext context,
    CampusEvent event, {
    required bool file,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: Text(
          file ? 'Share calendar file?' : 'Open the Calendar editor?',
        ),
        content: const Text(
          'Only the title, dates/times and venue are included. Private notes, source links and StudyDesk notifications stay here. Your calendar may sync to an account. Check the date and any Calendar alert before saving. Repeated handoffs can create copies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(file ? 'Share .ics' : 'Open Calendar'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent != true)
      return;
    try {
      if (file) {
        final data = utf8.encode(exportCampusEvent(event, reminders.now()));
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(data, mimeType: 'text/calendar')],
            fileNameOverrides: ['studydesk-event.ics'],
          ),
        );
        // Sharing or dismissing the sheet is not confirmation of calendar import.
        return;
      }
      final opened = await calendar.openEditor(event);
      if (context.mounted)
        _notice(
          context,
          opened
              ? 'Calendar editor opened. Save there to add it; StudyDesk does not know whether you saved.'
              : 'No Calendar editor was found. Try Share .ics instead.',
        );
    } catch (_) {
      if (context.mounted)
        _notice(
          context,
          'Couldn’t open the calendar handoff. The StudyDesk event is unchanged.',
        );
    }
  }

  Future<void> _openSource(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = await calendar.openSource(uri);
    } catch (_) {
      /* Keep the saved event. */
    }
    if (!opened && context.mounted)
      _notice(
        context,
        'Couldn’t open this link. The source text is still available here.',
      );
  }

  Future<void> _notificationSettings(BuildContext context) async {
    final message = await reminders.openSettings();
    if (context.mounted) _notice(context, message);
  }

  String _androidStatus(CampusEvent event) {
    final request = event.notification;
    if (request == null) return 'No StudyDesk notification selected.';
    final now = reminders.now();
    final target = campusStamp(request.target, use24Hour: use24Hour);
    if (!request.target.isAfter(now))
      return 'Target passed: $target. Delivery is not confirmed.';
    if (request.target.isAfter(now.add(eventReminderHorizon)))
      return 'Not queued: target is over 365 days away. Reopen StudyDesk when it is closer.';
    return switch (reminders.access) {
      NotificationAccess.allowed =>
        reminders.pendingFor(event) == null
            ? 'Not queued on Android'
            : 'Pending on Android · $target',
      NotificationAccess.notAsked =>
        'Not queued · edit and save to allow notifications',
      NotificationAccess.denied || NotificationAccess.blocked =>
        'Not queued · Android notifications blocked',
      NotificationAccess.checking => 'Checking Android notification status…',
      NotificationAccess.unavailable =>
        'Could not verify Android notification status',
    };
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([book, reminders]),
    builder: (context, _) {
      final event = book.find(eventId);
      final source = event == null ? null : campusSourceUri(event.link);
      return Scaffold(
        appBar: AppBar(title: const Text('Campus event')),
        body: SafeArea(
          top: false,
          child: DeskPage(
            clock: CampusClock.at(reminders.now()),
            children: [
              if (event == null)
                const DeskCard(child: Text('This event is no longer saved.'))
              else ...[
                DeskCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          Pill(
                            event.kind.label,
                            background: green.surface,
                            color: green.ink,
                          ),
                          Pill(
                            event.status,
                            background: gold.surface,
                            color: gold.ink,
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        event.title,
                        style: deskType(24, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      MetaLabel(
                        Icons.calendar_today_outlined,
                        _eventWhen(event, use24Hour: use24Hour),
                      ),
                      if (event.venue.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        MetaLabel(Icons.place_outlined, event.venue),
                      ],
                      if (event.source.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        MetaLabel(Icons.info_outline, event.source),
                      ],
                      if (source != null) ...[
                        const SizedBox(height: 6),
                        SelectableText(
                          event.link,
                          style: deskType(11, color: DeskColors.muted),
                        ),
                        TextButton.icon(
                          onPressed: () => _openSource(context, source),
                          icon: const Icon(Icons.north_east, size: 16),
                          label: const Text('Open source in browser'),
                        ),
                      ],
                      if (event.notes.isNotEmpty) ...[
                        const Divider(height: 18),
                        Text(
                          'Private notes',
                          style: deskType(12, weight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(event.notes),
                      ],
                      Wrap(
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: reminders.busy
                                ? null
                                : () => _edit(
                                    context,
                                    reminders,
                                    use24Hour,
                                    event,
                                  ),
                            child: const Text('Edit event'),
                          ),
                          TextButton(
                            onPressed: reminders.busy
                                ? null
                                : () => _delete(context, event),
                            child: const Text('Delete event'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DeskCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        'StudyDesk notification',
                        'Android can delay ordinary notifications. No Clock alarm is set.',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Preference: ${event.reminderLabel}',
                        style: deskType(13, weight: FontWeight.w800),
                      ),
                      if (event.reminder != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _androidStatus(event),
                          style: deskType(12, color: DeskColors.muted),
                        ),
                        if (reminders.access == NotificationAccess.allowed ||
                            reminders.access == NotificationAccess.unavailable)
                          TextButton(
                            onPressed: reminders.busy
                                ? null
                                : () async {
                                    final message = await reminders.refresh();
                                    if (context.mounted)
                                      _notice(context, message);
                                  },
                            child: const Text('Refresh Android status'),
                          ),
                      ],
                      if (event.reminder != null &&
                          (reminders.access == NotificationAccess.denied ||
                              reminders.access == NotificationAccess.blocked))
                        TextButton(
                          onPressed: reminders.busy
                              ? null
                              : () => _notificationSettings(context),
                          child: const Text(
                            'Open Android notification settings',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DeskCard(
                  color: blue.surface,
                  border: blue.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        'Device calendar',
                        'Optional copy. Set a Calendar alert in that app if you want one.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Changing or deleting this event here won’t update the Calendar copy. StudyDesk does not read your calendars.',
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _handoff(context, event, file: false),
                            icon: const Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                            ),
                            label: const Text('Add to device calendar'),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _handoff(context, event, file: true),
                            icon: const Icon(
                              Icons.ios_share_outlined,
                              size: 16,
                            ),
                            label: const Text('Share .ics'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
