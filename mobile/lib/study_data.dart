import 'dart:convert';

import 'package:flutter/services.dart';

const campusZone = 'Africa/Dar_es_Salaam';
const campusUtcOffset = Duration(hours: 3);
const weekDays = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String dayName(int weekday) => weekDays[weekday - 1];

enum ScheduleView { day, week }

class CampusClock {
  const CampusClock._(this.campusTime, this.weekStart);

  factory CampusClock.at(DateTime instant) {
    // Tanzania is UTC+3 year-round. Derive the campus date before selecting
    // a day or week; the phone can be using another time zone.
    final campus = instant.toUtc().add(campusUtcOffset);
    final date = DateTime.utc(campus.year, campus.month, campus.day);
    return CampusClock._(
      campus,
      date.subtract(Duration(days: campus.weekday - 1)),
    );
  }

  /// These UTC-backed fields represent campus wall time, not an alarm instant.
  final DateTime campusTime;
  final DateTime weekStart;

  int get weekday => campusTime.weekday;
  int get minute => campusTime.hour * 60 + campusTime.minute;
  String get weekKey => weekStart.toIso8601String().split('T').first;
  String get dateLabel =>
      '${dayName(weekday).substring(0, 3)} ${campusTime.day} ${_months[campusTime.month - 1]}';
  String get weekLabel {
    final end = weekStart.add(const Duration(days: 6));
    final start = weekStart.month == end.month
        ? '${weekStart.day}'
        : '${weekStart.day} ${_months[weekStart.month - 1]}';
    return '$start–${end.day} ${_months[end.month - 1]} ${end.year}';
  }
}

String campusDayKey(DateTime day) => day.toIso8601String().split('T').first;

DateTime campusDayOf(DateTime instant) {
  final wallTime = CampusClock.at(instant).campusTime;
  return DateTime.utc(wallTime.year, wallTime.month, wallTime.day);
}

DateTime? parseCampusDay(String key) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) return null;
  final day = DateTime.tryParse('${key}T00:00:00Z');
  return day != null && campusDayKey(day) == key ? day : null;
}

DateTime campusInstant(DateTime day, int minute) =>
    day.add(Duration(minutes: minute)).subtract(campusUtcOffset);

String campusDayLabel(DateTime day) =>
    '${dayName(day.weekday).substring(0, 3)}, ${day.day} ${_months[day.month - 1]} ${day.year}';

String clockText(int minute, {required bool use24Hour}) {
  final h = (minute ~/ 60).toString().padLeft(2, '0');
  final m = (minute % 60).toString().padLeft(2, '0');
  return formatTime('$h:$m', use24Hour: use24Hour);
}

String campusStamp(DateTime instant, {required bool use24Hour}) {
  final wallTime = CampusClock.at(instant);
  return '${campusDayLabel(wallTime.campusTime)} · ${clockText(wallTime.minute, use24Hour: use24Hour)} EAT';
}

int toMinutes(String time) {
  final parts = time.split(':');
  return int.parse(parts.first) * 60 + int.parse(parts.last);
}

String formatTime(String time, {required bool use24Hour}) {
  if (use24Hour) return time;
  final hour = int.parse(time.split(':').first);
  return '${(hour + 11) % 12 + 1}:${time.split(':').last} ${hour >= 12 ? 'PM' : 'AM'}';
}

String formatRange(String start, String end, {required bool use24Hour}) =>
    '${formatTime(start, use24Hour: use24Hour)}–${formatTime(end, use24Hour: use24Hour)}';

String formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return hours == 0 ? '${rest}m' : '${hours}h${rest > 0 ? ' ${rest}m' : ''}';
}

class Course {
  Course(this.code, Map<String, dynamic> json)
    : title = json['title'] as String,
      tone = json['tone'] as String,
      lecturer = json['lecturer'] as String,
      focus = json['focus'] as String;

  final String code;
  final String title;
  final String tone;
  final String lecturer;
  final String focus;
}

class Session {
  Session.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      day = json['day'] as int,
      start = json['start'] as String,
      end = json['end'] as String,
      code = json['code'] as String?,
      kind = json['kind'] as String,
      venue = json['venue'] as String;

  final String id;
  final int day;
  final String start;
  final String end;
  final String? code;
  final String kind;
  final String venue;

  int get minutes => toMinutes(end) - toMinutes(start);
  String get kindLabel => switch (kind) {
    'lecture' => 'Lecture',
    'practical' => 'Practical / Tutorial',
    _ => 'Campus activity',
  };
}

class UpcomingSession {
  const UpcomingSession(this.session, this.daysAhead, this.inProgress);
  final Session session;
  final int daysAhead;
  final bool inProgress;

  String get dayLabel => switch (daysAhead) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => dayName(session.day),
  };
}

class StudyBlock {
  StudyBlock.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      day = json['day'] as int,
      start = json['start'] as String,
      end = json['end'] as String,
      code = json['code'] as String,
      title = json['title'] as String,
      work = json['work'] as String,
      output = json['output'] as String;

  final String id;
  final int day;
  final String start;
  final String end;
  final String code;
  final String title;
  final String work;
  final String output;

  int get minutes => toMinutes(end) - toMinutes(start);
}

class GuideSection {
  GuideSection.fromJson(Map<String, dynamic> json)
    : title = json['title'] as String,
      body = json['body'] as String;
  final String title;
  final String body;
}

class StudyGuide {
  StudyGuide.fromJson(Map<String, dynamic> json)
    : title = json['title'] as String,
      source = json['source'] as String,
      intro = json['intro'] as String,
      exercise = json['exercise'] as String,
      sections = List.unmodifiable(
        (json['sections'] as List<dynamic>).map(
          (item) => GuideSection.fromJson(item as Map<String, dynamic>),
        ),
      );

  final String title;
  final String source;
  final String intro;
  final String exercise;
  final List<GuideSection> sections;
}

class StudyData {
  StudyData._({
    required this.cohort,
    required this.term,
    required this.year,
    required this.source,
    required this.sourcePage,
    required this.courses,
    required this.sessions,
    required this.blocks,
    required this.guides,
  });

  static Future<StudyData> load(AssetBundle bundle) async {
    final files = await Future.wait([
      bundle.loadString('assets/data/semester.json'),
      bundle.loadString('assets/data/plan.json'),
      bundle.loadString('assets/data/guides.json'),
    ]);
    final semester = jsonDecode(files[0]) as Map<String, dynamic>;
    if (semester['timezone'] != campusZone) {
      throw const FormatException(
        'StudyDesk currently supports the UAUT campus time zone only.',
      );
    }
    final plan = jsonDecode(files[1]) as List<dynamic>;
    final notes = jsonDecode(files[2]) as Map<String, dynamic>;
    final courses = (semester['courses'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, Course(key, value as Map<String, dynamic>)),
    );
    final sessions =
        (semester['sessions'] as List<dynamic>)
            .map((item) => Session.fromJson(item as Map<String, dynamic>))
            .toList()
          ..sort(
            (a, b) => a.day != b.day
                ? a.day.compareTo(b.day)
                : a.start.compareTo(b.start),
          );
    return StudyData._(
      cohort: semester['cohort'] as String,
      term: semester['term'] as String,
      year: semester['year'] as String,
      source: semester['source'] as String,
      sourcePage: semester['sourcePage'] as int,
      courses: Map.unmodifiable(courses),
      sessions: List.unmodifiable(sessions),
      blocks: List.unmodifiable(
        plan.map((item) => StudyBlock.fromJson(item as Map<String, dynamic>)),
      ),
      guides: Map.unmodifiable(
        notes.map(
          (key, value) =>
              MapEntry(key, StudyGuide.fromJson(value as Map<String, dynamic>)),
        ),
      ),
    );
  }

  final String cohort;
  final String term;
  final String year;
  final String source;
  final int sourcePage;
  final Map<String, Course> courses;
  final List<Session> sessions;
  final List<StudyBlock> blocks;
  final Map<String, StudyGuide> guides;

  String get termLabel => '$term · $year';
  String titleFor(Session session) =>
      courses[session.code]?.title ??
      (session.kind == 'chapel' ? 'Chapel' : session.code ?? 'Campus activity');
  List<Session> onDay(int weekday) => sessions
      .where((session) => session.day == weekday)
      .toList(growable: false);

  UpcomingSession? upcoming(CampusClock clock) {
    for (var offset = 0; offset <= 7; offset++) {
      final day = (clock.weekday + offset - 1) % 7 + 1;
      for (final session in onDay(day)) {
        if (offset > 0 || toMinutes(session.end) > clock.minute) {
          return UpcomingSession(
            session,
            offset,
            offset == 0 && toMinutes(session.start) <= clock.minute,
          );
        }
      }
    }
    return null;
  }
}
