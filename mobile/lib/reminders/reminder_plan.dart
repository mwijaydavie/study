import 'dart:convert';

import '../study_data.dart';

const reminderHorizonDays = 14;
const reminderLeadMinutes = <int>[5, 15, 30, 60];

class ClassOccurrence {
  const ClassOccurrence(this.session, this.campusDay);
  final Session session;

  /// UTC midnight is a calendar-date representation, not the trigger instant.
  final DateTime campusDay;

  DateTime get startsAt => campusInstant(campusDay, toMinutes(session.start));

  DateTime target(int lead) => startsAt.subtract(Duration(minutes: lead));

  List<int> availableLeads(DateTime now) => reminderLeadMinutes
      .where((lead) => target(lead).isAfter(now))
      .toList(growable: false);
}

/// An individually confirmed notification. The Android side stores these and
/// removes them when delivered, cancelled or expired. A test has no class date.
class ReminderRequest {
  const ReminderRequest({
    required this.key,
    required this.target,
    required this.expires,
    required this.title,
    required this.body,
    this.sessionId,
    this.eventId,
    this.dayKey,
    this.lead,
    this.revision,
  });

  factory ReminderRequest.fromPlatform(Map<Object?, Object?> item) =>
      ReminderRequest(
        key: item['key'] as String,
        target: DateTime.fromMillisecondsSinceEpoch(
          item['target'] as int,
          isUtc: true,
        ),
        expires: DateTime.fromMillisecondsSinceEpoch(
          item['expires'] as int,
          isUtc: true,
        ),
        title: item['title'] as String,
        body: item['body'] as String,
        sessionId: item['sessionId'] as String?,
        eventId: item['eventId'] as String?,
        dayKey: item['day'] as String?,
        lead: item['lead'] as int?,
        revision: item['revision'] as String?,
      );

  final String key;
  final DateTime target;
  final DateTime expires;
  final String title;
  final String body;
  final String? sessionId;
  final String? eventId;
  final String? dayKey;
  final int? lead;
  final String? revision;

  bool get isTest => key == 'test';
  bool get isEvent => eventId != null;

  Map<String, Object?> toPlatform() => {
    'key': key,
    'target': target.millisecondsSinceEpoch,
    'expires': expires.millisecondsSinceEpoch,
    'title': title,
    'body': body,
    if (sessionId != null) 'sessionId': sessionId,
    if (eventId != null) 'eventId': eventId,
    if (dayKey != null) 'day': dayKey,
    if (lead != null) 'lead': lead,
    if (revision != null) 'revision': revision,
  };
}

class ClassReminderPlan {
  const ClassReminderPlan(this.data);
  final StudyData data;

  Iterable<Session> get classes =>
      data.sessions.where((item) => item.code != null);

  String _revision(Session session) => jsonEncode([
    data.cohort,
    data.term,
    data.year,
    data.source,
    data.sourcePage,
    session.id,
    session.code,
    session.day,
    session.kind,
    session.start,
    session.end,
    session.venue,
    data.titleFor(session),
  ]);

  List<ClassOccurrence> choices(Session session, DateTime now) {
    if (session.code == null) return const [];
    final today = campusDayOf(now);
    final dates = <ClassOccurrence>[];
    for (var offset = 0; offset < reminderHorizonDays; offset++) {
      final day = today.add(Duration(days: offset));
      if (day.weekday != session.day) continue;
      final occurrence = ClassOccurrence(session, day);
      if (occurrence.availableLeads(now).isNotEmpty) dates.add(occurrence);
    }
    return dates;
  }

  ClassOccurrence? occurrence(String? sessionId, String? dayKey) {
    final day = dayKey == null ? null : parseCampusDay(dayKey);
    if (day == null) return null;
    for (final session in classes) {
      if (session.id == sessionId && session.day == day.weekday) {
        return ClassOccurrence(session, day);
      }
    }
    return null;
  }

  ReminderRequest? create(ClassOccurrence choice, int lead, DateTime now) {
    final day = campusDayKey(choice.campusDay);
    final current = occurrence(choice.session.id, day);
    if (current == null ||
        _revision(current.session) != _revision(choice.session) ||
        !reminderLeadMinutes.contains(lead) ||
        !_inWindow(current.campusDay, now) ||
        !current.target(lead).isAfter(now)) {
      return null;
    }
    return _classRequest(current, lead);
  }

  ReminderRequest _classRequest(ClassOccurrence choice, int lead) {
    final session = choice.session;
    final day = campusDayKey(choice.campusDay);
    return ReminderRequest(
      key: 'class:${session.id}:$day',
      target: choice.target(lead),
      // Never post an inexact notification for a class that has already started.
      expires: choice.startsAt,
      title: '${session.code} · ${session.kindLabel}',
      body:
          '${data.titleFor(session)} · ${session.start} EAT · ${session.venue}',
      sessionId: session.id,
      dayKey: day,
      lead: lead,
      revision: _revision(session),
    );
  }

  bool _inWindow(DateTime day, DateTime now) {
    final today = campusDayOf(now);
    return !day.isBefore(today) &&
        day.isBefore(today.add(const Duration(days: reminderHorizonDays)));
  }

  bool keep(ReminderRequest saved, DateTime now) {
    if (saved.isEvent || !saved.expires.isAfter(now)) return false;
    if (saved.isTest)
      return saved.target.isBefore(now.add(const Duration(hours: 1)));
    final current = occurrence(saved.sessionId, saved.dayKey);
    final lead = saved.lead;
    if (current == null ||
        lead == null ||
        !reminderLeadMinutes.contains(lead) ||
        !_inWindow(current.campusDay, now))
      return false;
    final expected = _classRequest(current, lead);
    return saved.key == expected.key &&
        saved.revision == expected.revision &&
        saved.target == expected.target &&
        saved.expires == expected.expires;
  }

  ClassOccurrence? openFromTap(
    String? sessionId,
    String? dayKey,
    String? revision,
  ) {
    final current = occurrence(sessionId, dayKey);
    return current != null && revision == _revision(current.session)
        ? current
        : null;
  }
}
