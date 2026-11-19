import 'package:flutter/material.dart';

import '../campus/campus_events.dart';
import '../design.dart';
import '../reminders/reminder_plan.dart';
import '../reminders/reminders.dart';
import '../study_data.dart';

class CampusEventEditor extends StatefulWidget {
  const CampusEventEditor({
    super.key,
    required this.reminders,
    required this.use24Hour,
    this.event,
  });
  final ReminderController reminders;
  final bool use24Hour;
  final CampusEvent? event;

  @override
  State<CampusEventEditor> createState() => _CampusEventEditorState();
}

class _CampusEventEditorState extends State<CampusEventEditor> {
  final _form = GlobalKey<FormState>();
  CampusEvent? get existing => widget.event;
  late final _id = existing?.id ?? CampusEvent.makeId();
  late final _title = TextEditingController(text: existing?.title);
  late final _venue = TextEditingController(text: existing?.venue);
  late final _source = TextEditingController(text: existing?.source);
  late final _link = TextEditingController(text: existing?.link);
  late final _notes = TextEditingController(text: existing?.notes);
  late CampusEventKind _kind = existing?.kind ?? CampusEventKind.other;
  late bool _checked = existing?.dateChecked ?? false;
  late bool _allDay = existing?.allDay ?? false;
  late bool _hasEnd = existing?.through != null;
  late DateTime? _day = existing?.day;
  late DateTime? _through = existing?.through;
  late int? _minute = existing?.minute;
  late int? _endMinute = existing?.endMinute;
  late int? _reminder = existing?.reminder;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final field in [_title, _venue, _source, _link, _notes]) {
      field.dispose();
    }
    super.dispose();
  }

  DateTime _pickerDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _pickDate({required bool end}) async {
    final today = campusDayOf(widget.reminders.now());
    final first = DateTime(campusEventDateStart);
    final last = DateTime(campusEventDateEnd, 12, 31);
    final candidate = _pickerDate((end ? _through ?? _day : _day) ?? today);
    final initial = candidate.isBefore(first)
        ? first
        : candidate.isAfter(last)
        ? last
        : candidate;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      currentDate: _pickerDate(today),
      firstDate: first,
      lastDate: last,
      helpText: end ? 'End date (EAT)' : 'Start date (EAT)',
    );
    if (date == null || !mounted) return;
    final day = DateTime.utc(date.year, date.month, date.day);
    setState(() {
      if (end) {
        if (_through != day) _checked = false;
        _through = day;
      } else {
        if (_day != day) _checked = false;
        _day = day;
      }
    });
  }

  Future<void> _pickTime({required bool end}) async {
    final initial = (end ? _endMinute ?? _minute : _minute) ?? 9 * 60;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      helpText: end ? 'End time (EAT)' : 'Start time (EAT)',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(alwaysUse24HourFormat: widget.use24Hour),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final minute = time.hour * 60 + time.minute;
    setState(() {
      if (end) {
        if (_endMinute != minute) _checked = false;
        _endMinute = minute;
      } else {
        if (_minute != minute) _checked = false;
        _minute = minute;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      setState(() => _error = 'Check the highlighted fields before saving.');
      return;
    }
    final startDay = _day;
    if (startDay == null || (!_allDay && _minute == null)) {
      setState(
        () =>
            _error = 'Choose a start date and, for timed events, a start time.',
      );
      return;
    }
    if (_hasEnd && (_through == null || (!_allDay && _endMinute == null))) {
      setState(
        () => _error =
            'Finish selecting the end date and time or turn off the end.',
      );
      return;
    }
    final CampusEvent event;
    try {
      event = CampusEvent(
        id: _id,
        title: _title.text,
        kind: _kind,
        day: startDay,
        minute: _allDay ? null : _minute,
        through: _hasEnd ? _through : null,
        endMinute: _hasEnd && !_allDay ? _endMinute : null,
        venue: _venue.text,
        source: _source.text,
        link: _link.text,
        notes: _notes.text,
        dateChecked: _checked,
        reminder: _reminder,
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final change = await widget.reminders.saveEvent(event);
    if (!mounted) return;
    if (change.saved) {
      if (ModalRoute.of(context)?.isCurrent == true)
        Navigator.of(context).pop(change.message);
    } else {
      setState(() {
        _saving = false;
        _error = change.message;
      });
    }
  }

  Widget _input(
    String label,
    TextEditingController controller,
    int max, {
    int lines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLength: max,
      maxLines: lines,
      keyboardType: keyboard,
      validator: validate,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
    ),
  );

  String _time(int? minutes, String fallback) => minutes == null
      ? fallback
      : clockText(minutes, use24Hour: widget.use24Hour);

  Widget _whenButtons({required bool end}) {
    final day = end ? _through : _day;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        OutlinedButton.icon(
          key: Key(end ? 'event-end-date' : 'event-start-date'),
          onPressed: () => _pickDate(end: end),
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(day == null ? 'Choose date' : campusDayLabel(day)),
        ),
        if (!_allDay)
          OutlinedButton.icon(
            key: Key(end ? 'event-end-time' : 'event-start-time'),
            onPressed: () => _pickTime(end: end),
            icon: const Icon(Icons.schedule_outlined, size: 16),
            label: Text(_time(end ? _endMinute : _minute, 'Choose time')),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<String>(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          existing == null ? 'Add campus event' : 'Edit campus event',
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: AbsorbPointer(
            absorbing: _saving,
            child: DeskPage(
              clock: CampusClock.at(widget.reminders.now()),
              children: [
                const SectionTitle(
                  'Event details',
                  'Manual entry · Date and time are in Dar es Salaam (EAT).',
                ),
                const SizedBox(height: 12),
                _input(
                  'Event title',
                  _title,
                  120,
                  validate: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter an event title.'
                      : null,
                ),
                Text('Category', style: deskType(13, weight: FontWeight.w800)),
                DropdownButton<CampusEventKind>(
                  isExpanded: true,
                  value: _kind,
                  items: [
                    for (final kind in CampusEventKind.values)
                      DropdownMenuItem(value: kind, child: Text(kind.label)),
                  ],
                  onChanged: (kind) {
                    if (kind != null) setState(() => _kind = kind);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('All day'),
                  value: _allDay,
                  onChanged: (value) => setState(() {
                    _allDay = value;
                    _reminder = null;
                    _checked = false;
                  }),
                ),
                Text(
                  'Starts (EAT)',
                  style: deskType(13, weight: FontWeight.w800),
                ),
                _whenButtons(end: false),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_allDay ? 'Add a last day' : 'Add an end time'),
                  value: _hasEnd,
                  onChanged: (value) => setState(() {
                    _hasEnd = value;
                    if (value) _through ??= _day;
                    _checked = false;
                  }),
                ),
                if (_hasEnd) ...[
                  Text(
                    _allDay ? 'Last day (inclusive)' : 'Ends (EAT)',
                    style: deskType(13, weight: FontWeight.w800),
                  ),
                  _whenButtons(end: true),
                ],
                const SizedBox(height: 12),
                _input('Venue (optional)', _venue, 120),
                _input('Source or organizer (optional)', _source, 160),
                _input(
                  'https:// source link (optional)',
                  _link,
                  700,
                  keyboard: TextInputType.url,
                  validate: (value) =>
                      (value ?? '').trim().isEmpty ||
                          campusSourceUri(value!) != null
                      ? null
                      : 'Use a full https:// link.',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I checked the date'),
                  subtitle: const Text(
                    'Your own check, not an official university verification.',
                  ),
                  value: _checked,
                  onChanged: (value) => setState(() => _checked = value),
                ),
                const SizedBox(height: 10),
                _input('Private notes (optional)', _notes, 1200, lines: 3),
                const DeskCard(
                  color: DeskColors.paper,
                  child: Text(
                    'Private notes and source details stay in StudyDesk when you send an event to Calendar.',
                  ),
                ),
                const SizedBox(height: 14),
                const SectionTitle(
                  'StudyDesk notification',
                  'Optional Android notification; this does not change Calendar alerts.',
                ),
                DropdownButton<int>(
                  key: const Key('campus-reminder-choice'),
                  isExpanded: true,
                  value: _reminder ?? -1,
                  items: [
                    const DropdownMenuItem(value: -1, child: Text('Off')),
                    if (_allDay)
                      const DropdownMenuItem(
                        value: 0,
                        child: Text('09:00 EAT on the first day'),
                      )
                    else
                      for (final lead in reminderLeadMinutes)
                        DropdownMenuItem(
                          value: lead,
                          child: Text('$lead minutes before'),
                        ),
                  ],
                  onChanged: (choice) {
                    if (choice != null)
                      setState(() => _reminder = choice < 0 ? null : choice);
                  },
                ),
                if (_error case final message?) ...[
                  const SizedBox(height: 10),
                  DeskCard(
                    color: peach.surface,
                    border: peach.surface,
                    child: Text(message, style: deskType(12, color: peach.ink)),
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton(
                  key: const Key('save-campus-event'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save event'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
