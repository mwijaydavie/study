import 'dart:convert';

import 'package:flutter/services.dart';

import '../study_data.dart';
import 'campus_events.dart';

Map<String, Object?> calendarDraft(CampusEvent event) => {
  'title': event.title,
  'venue': event.venue,
  'allDay': event.allDay,
  'begin': (event.allDay ? event.day : event.start).millisecondsSinceEpoch,
  'end': (event.allDay ? event.exclusiveAllDayEnd : event.end)
      ?.millisecondsSinceEpoch,
};

abstract interface class DeviceCalendar {
  /// True only if Android launched an editor, not if the event was saved.
  Future<bool> openEditor(CampusEvent event);
  Future<bool> openSource(Uri uri);
}

class AndroidCampusPlatform implements CampusEventStorage, DeviceCalendar {
  const AndroidCampusPlatform();

  static const _channel = MethodChannel('tz.altraware.studydesk/campus_events');

  @override
  Future<String?> readEvents() => _channel.invokeMethod<String>('readEvents');

  @override
  Future<void> writeEvents(String snapshot) =>
      _channel.invokeMethod<void>('writeEvents', snapshot);

  @override
  Future<bool> openEditor(CampusEvent event) async =>
      await _channel.invokeMethod<bool>(
        'addToCalendar',
        calendarDraft(event),
      ) ??
      false;

  @override
  Future<bool> openSource(Uri uri) async =>
      await _channel.invokeMethod<bool>('openSource', uri.toString()) ?? false;
}

String _date(DateTime day) => campusDayKey(day).replaceAll('-', '');
String _stamp(DateTime instant) {
  final utc = instant.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${_date(utc)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

String _escape(String text) => text
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
    .replaceAll('\\', '\\\\')
    .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n')
    .replaceAll(',', r'\,')
    .replaceAll(';', r'\;');

// iCalendar folds at 75 octets. Don't split a UTF-8 character across folds.
String _fold(String line) {
  final out = StringBuffer();
  var bytes = 0;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final length = utf8.encode(char).length;
    if (bytes + length > 75) {
      out.write('\r\n ');
      bytes = 1;
    }
    out.write(char);
    bytes += length;
  }
  return out.toString();
}

String exportCampusEvent(CampusEvent event, DateTime now) {
  return [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//StudyDesk//Campus events//EN',
        'BEGIN:VEVENT',
        'UID:${event.id}@studydesk.local',
        'DTSTAMP:${_stamp(now)}',
        if (event.allDay) ...[
          'DTSTART;VALUE=DATE:${_date(event.day)}',
          'DTEND;VALUE=DATE:${_date(event.exclusiveAllDayEnd)}',
        ] else ...[
          'DTSTART:${_stamp(event.start)}',
          if (event.end case final end?) 'DTEND:${_stamp(end)}',
        ],
        'SUMMARY:${_escape(event.title)}',
        if (event.venue.isNotEmpty) 'LOCATION:${_escape(event.venue)}',
        'CLASS:PRIVATE',
        'END:VEVENT',
        'END:VCALENDAR',
      ].map(_fold).join('\r\n') +
      '\r\n';
}
