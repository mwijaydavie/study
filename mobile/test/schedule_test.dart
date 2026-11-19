import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studydesk/study_data.dart';
import 'package:studydesk/study_files.dart';
import 'package:studydesk/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'midnight and Monday follow EAT even when UTC shows the previous date',
    () {
      final before = CampusClock.at(DateTime.parse('2026-11-18T20:59:59Z'));
      final after = CampusClock.at(DateTime.parse('2026-11-18T21:00:00Z'));
      expect(before.weekday, DateTime.wednesday);
      expect(after.weekday, DateTime.thursday);
      expect(after.minute, 0);
      expect(after.weekKey, '2026-11-16');
      final monday = CampusClock.at(DateTime.parse('2026-11-22T21:00:00Z'));
      expect(monday.weekday, DateTime.monday);
      expect(monday.weekKey, '2026-11-23');
    },
  );

  test(
    'bundled data keeps Thursday BIT Year 2, Chapel, guides and offline PDF',
    () async {
      final data = await StudyData.load(rootBundle);
      expect(data.sessions.length, 12);
      expect(data.courses.length, 6);
      expect(data.sourcePage, 2);
      expect(
        data
            .onDay(DateTime.thursday)
            .map((item) => (item.code, item.start, item.end, item.venue)),
        [
          ('IS237', '08:00', '09:30', 'Computer Lab'),
          ('FN200', '11:00', '14:00', 'BH301'),
        ],
      );
      expect(
        data.onDay(DateTime.wednesday).any((item) => item.kind == 'chapel'),
        true,
      );
      expect(data.guides['ooad']?.sections.length, 3);
      final bytes = await rootBundle.load(timetableFile.asset);
      expect(
        ascii.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, 5)),
        '%PDF-',
      );
    },
  );

  test(
    'next class switches at session boundaries and rolls across the weekend',
    () async {
      final data = await StudyData.load(rootBundle);
      UpcomingSession? at(String instant) =>
          data.upcoming(CampusClock.at(DateTime.parse(instant)));
      expect(at('2026-11-19T05:00:00Z')?.inProgress, true);
      expect(at('2026-11-19T06:30:00Z')?.session.code, 'FN200');
      expect(at('2026-11-20T12:30:00Z')?.session.code, 'CS243');
      expect(at('2026-11-20T12:30:00Z')?.daysAhead, 3);
      expect(formatTime('00:00', use24Hour: false), '12:00 AM');
      expect(formatTime('12:05', use24Hour: false), '12:05 PM');
    },
  );

  test('settings and checklist survive a separate workspace load', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final workspace = Workspace(prefs);
    await workspace.setTimeFormat(false);
    await workspace.setDefaultView(ScheduleView.week);
    workspace.setView(ScheduleView.day); // temporary view, not saved as default
    await workspace.toggleTask('2026-11-16', 'ooad');
    workspace.dispose();
    await prefs.reload();

    final reloaded = Workspace(prefs);
    expect(reloaded.use24Hour, false);
    expect(reloaded.view, ScheduleView.week);
    expect(reloaded.doneFor('2026-11-16'), {'ooad'});
    expect(reloaded.doneFor('2026-11-23'), isEmpty);
    await reloaded.clearWeek('2026-11-16');
    expect(reloaded.doneFor('2026-11-16'), isEmpty);
    expect(reloaded.view, ScheduleView.week);
    reloaded.dispose();
  });
}
