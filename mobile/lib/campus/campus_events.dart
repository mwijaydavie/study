import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../reminders/reminder_plan.dart';
import '../study_data.dart';

const campusEventDateStart = 2000;
const campusEventDateEnd = 2100;
const eventReminderHorizon = Duration(days: 365);
const eventReminderCapacity = 32;
const allDayReminderMinute = 9 * 60;
final _eventId = RegExp(r'^[a-f0-9]{32}$');

enum CampusEventKind {
  seminar('Seminar'),
  workshop('Workshop'),
  lab('Lab'),
  exam('Exam'),
  deadline('Deadline'),
  other('Other');

  const CampusEventKind(this.label);
  final String label;
}

Uri? campusSourceUri(String text) {
  final uri = Uri.tryParse(text.trim());
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

bool _calendarDay(DateTime day) =>
    day.isUtc &&
    day == DateTime.utc(day.year, day.month, day.day) &&
    day.year >= campusEventDateStart &&
    day.year <= campusEventDateEnd;

class CampusEvent {
  CampusEvent({
    required this.id,
    required String title,
    required this.kind,
    required this.day,
    this.minute,
    this.through,
    this.endMinute,
    String venue = '',
    String source = '',
    String link = '',
    String notes = '',
    this.dateChecked = false,
    this.reminder,
  }) : title = title.trim(),
       venue = venue.trim(),
       source = source.trim(),
       link = link.trim(),
       notes = notes.trim() {
    if (!_eventId.hasMatch(id)) {
      throw const FormatException('Invalid event ID.');
    }
    if (this.title.isEmpty || this.title.length > 120) {
      throw const FormatException(
        'Enter an event title (up to 120 characters).',
      );
    }
    if (!_calendarDay(day) || (through != null && !_calendarDay(through!))) {
      throw const FormatException('Choose a valid event date.');
    }
    if (minute != null && (minute! < 0 || minute! >= 1440)) {
      throw const FormatException('Choose a valid start time.');
    }
    if (allDay) {
      if (endMinute != null || (through != null && through!.isBefore(day))) {
        throw const FormatException(
          'The last all-day date must be on or after the first date.',
        );
      }
    } else {
      if ((through == null) != (endMinute == null) ||
          (endMinute != null && (endMinute! < 0 || endMinute! >= 1440))) {
        throw const FormatException(
          'Choose both an end date and end time, or leave out the end.',
        );
      }
      if (end case final instant? when !instant.isAfter(start)) {
        throw const FormatException(
          'End must be after the start in campus time.',
        );
      }
    }
    if (reminder != null &&
        (allDay ? reminder != 0 : !reminderLeadMinutes.contains(reminder))) {
      throw const FormatException('Choose a valid notification time.');
    }
    if (this.venue.length > 120 ||
        this.source.length > 160 ||
        this.link.length > 700 ||
        this.notes.length > 1200) {
      throw const FormatException('Some event details are too long.');
    }
    if (this.link.isNotEmpty && campusSourceUri(this.link) == null) {
      throw const FormatException('A source link must be a full https:// URL.');
    }
  }

  factory CampusEvent.fromJson(Map<String, dynamic> json) => CampusEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    kind: CampusEventKind.values.byName(json['kind'] as String),
    day:
        parseCampusDay(json['day'] as String) ??
        (throw const FormatException('Invalid date')),
    minute: json['minute'] as int?,
    through: json['through'] == null
        ? null
        : parseCampusDay(json['through'] as String) ??
              (throw const FormatException('Invalid end date')),
    endMinute: json['endMinute'] as int?,
    venue: json['venue'] as String,
    source: json['source'] as String,
    link: json['link'] as String,
    notes: json['notes'] as String,
    dateChecked: json['dateChecked'] as bool,
    reminder: json['reminder'] as int?,
  );

  static String makeId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  final String id, title, venue, source, link, notes;
  final CampusEventKind kind;
  final DateTime day;
  final int? minute;

  /// Optional end day: inclusive for all-day, or paired with [endMinute].
  final DateTime? through;
  final int? endMinute;
  final bool dateChecked;

  /// Null = off, 0 = all-day morning, positive = minutes before a timed event.
  final int? reminder;

  bool get allDay => minute == null;
  DateTime get start => campusInstant(day, minute ?? 0);
  DateTime get exclusiveAllDayEnd =>
      (through ?? day).add(const Duration(days: 1));
  DateTime? get end => allDay
      ? campusInstant(exclusiveAllDayEnd, 0)
      : through == null
      ? null
      : campusInstant(through!, endMinute!);
  bool isPast(DateTime now) => !(end ?? start).isAfter(now);
  String get status =>
      dateChecked ? 'Manual · date checked by you' : 'Manual · unconfirmed';
  String get reminderLabel => switch (reminder) {
    null => 'Off',
    0 => '09:00 EAT on the first day',
    final lead => '$lead minutes before',
  };
  String get alertKey => 'event:$id';
  // Only fields that affect the scheduled request or exported event. Private
  // notes, source and the checkmark do not rewrite a valid queued notification.
  String get revision => jsonEncode([
    id,
    title,
    kind.name,
    campusDayKey(day),
    minute,
    through == null ? null : campusDayKey(through!),
    endMinute,
    venue,
    reminder,
  ]);

  ReminderRequest? get notification {
    final lead = reminder;
    if (lead == null) return null;
    return ReminderRequest(
      key: alertKey,
      eventId: id,
      revision: revision,
      lead: lead,
      target: allDay
          ? campusInstant(day, allDayReminderMinute)
          : start.subtract(Duration(minutes: lead)),
      // A timed notification never posts after the start. All-day alerts are
      // only for the first day, even when the event runs longer.
      expires: allDay ? campusInstant(day, 1440) : start,
      title: title,
      body:
          '${kind.label} · ${allDay ? 'All day' : '${clockText(minute!, use24Hour: true)} EAT'}${venue.isEmpty ? '' : ' · $venue'}',
    );
  }

  bool matches(ReminderRequest pending, DateTime now) {
    final expected = notification;
    return expected != null &&
        pending.key == expected.key &&
        pending.eventId == id &&
        pending.revision == expected.revision &&
        pending.title == expected.title &&
        pending.body == expected.body &&
        pending.lead == expected.lead &&
        pending.target == expected.target &&
        pending.expires == expected.expires &&
        pending.expires.isAfter(now);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'day': campusDayKey(day),
    'minute': minute,
    'through': through == null ? null : campusDayKey(through!),
    'endMinute': endMinute,
    'venue': venue,
    'source': source,
    'link': link,
    'notes': notes,
    'dateChecked': dateChecked,
    'reminder': reminder,
  };
}

abstract interface class CampusEventStorage {
  Future<String?> readEvents();
  Future<void> writeEvents(String snapshot);
}

/// The book is separate from the timetable and Android's pending notifications.
/// Writes are coordinated by the reminder controller (cancel, persist, schedule).
class CampusEventBook extends ChangeNotifier {
  CampusEventBook._(this._storage, this._items, {required this.available});

  static const maxEvents = 100;
  final CampusEventStorage _storage;
  Map<String, CampusEvent> _items;
  final bool available;
  bool _disposed = false;

  static Future<CampusEventBook> load(CampusEventStorage storage) async {
    try {
      final raw = await storage.readEvents().timeout(
        const Duration(seconds: 3),
      );
      final items = <String, CampusEvent>{};
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['version'] != 1)
          throw const FormatException('Unknown campus data version');
        final rows = data['items'] as List<dynamic>;
        if (rows.length > maxEvents)
          throw const FormatException('Too many events');
        for (final row in rows) {
          final event = CampusEvent.fromJson(row as Map<String, dynamic>);
          if (items.containsKey(event.id))
            throw const FormatException('Duplicate event ID');
          items[event.id] = event;
        }
      }
      return CampusEventBook._(storage, items, available: true);
    } catch (_) {
      // Preserve a snapshot we couldn't read instead of overwriting it.
      return CampusEventBook._(storage, {}, available: false);
    }
  }

  CampusEvent? find(String? id) => _items[id];
  Iterable<CampusEvent> get events => _items.values;
  bool canSave(CampusEvent event) =>
      available && (_items.containsKey(event.id) || _items.length < maxEvents);

  List<CampusEvent> listAt(DateTime now, {required bool past}) {
    return _items.values.where((event) => event.isPast(now) == past).toList()
      ..sort((a, b) {
        final byStart = past
            ? b.start.compareTo(a.start)
            : a.start.compareTo(b.start);
        return byStart == 0 ? a.title.compareTo(b.title) : byStart;
      });
  }

  Future<void> save(CampusEvent event) async {
    if (!canSave(event)) throw StateError('Campus storage unavailable or full');
    await _write({..._items, event.id: event});
  }

  Future<void> remove(String id) => _write({..._items}..remove(id));

  Future<void> _write(Map<String, CampusEvent> next) async {
    if (!available || _disposed) throw StateError('Campus storage unavailable');
    await _storage.writeEvents(
      jsonEncode({
        'version': 1,
        'items': next.values.map((event) => event.toJson()).toList(),
      }),
    );
    _items = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
