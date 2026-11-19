import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studydesk/campus/campus_calendar.dart';
import 'package:studydesk/campus/campus_events.dart';
import 'package:studydesk/study_data.dart';

import 'support/memory_campus_storage.dart';

const testEventId = '0123456789abcdef0123456789abcdef';

CampusEvent _fixture({
  String title = 'Example workshop',
  int? minute = 10,
  DateTime? through,
  int? endMinute,
  int? reminder,
}) => CampusEvent(
  id: testEventId,
  title: title,
  kind: CampusEventKind.workshop,
  day: DateTime.utc(2026, 11, 19),
  minute: minute,
  through: through,
  endMinute: endMinute,
  venue: 'Test venue; room \\2',
  link: 'https://example.test/reference',
  source: 'Manual example only',
  notes: 'Private notes never shared',
  reminder: reminder,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.parse('2026-11-18T12:59:59-08:00');

  test(
    'validates dated EAT intervals and keeps timed instants zone independent',
    () {
      final day = DateTime.utc(2026, 11, 19);
      final timed = _fixture(through: day, endMinute: 40, reminder: 15);
      expect(timed.start, DateTime.utc(2026, 11, 18, 21, 10));
      expect(timed.end, DateTime.utc(2026, 11, 18, 21, 40));
      expect(timed.notification?.target, DateTime.utc(2026, 11, 18, 20, 55));
      expect(timed.notification?.expires, timed.start);
      expect(timed.isPast(now), false);
      expect(timed.isPast(timed.start), false);
      expect(timed.isPast(timed.end!), true);
      expect(timed.status, 'Manual · unconfirmed');
      expect(_fixture().end, isNull);
      expect(
        () => _fixture(through: day, endMinute: 10),
        throwsFormatException,
      );
      expect(() => _fixture(through: day, endMinute: 9), throwsFormatException);
      expect(() => _fixture(through: day), throwsFormatException);
      expect(() => _fixture(minute: 1440), throwsFormatException);
      expect(() => _fixture(reminder: 0), throwsFormatException);
      expect(
        () => CampusEvent.fromJson({...timed.toJson(), 'day': '2026-02-30'}),
        throwsFormatException,
      );
      expect(
        _fixture(
          minute: 23 * 60,
          through: DateTime.utc(2026, 11, 20),
          endMinute: 5,
        ).end,
        DateTime.utc(2026, 11, 19, 21, 5),
      );
    },
  );

  test(
    'all-day dates are inclusive in StudyDesk; reminder expires on day one',
    () {
      final fullDays = _fixture(
        minute: null,
        through: DateTime.utc(2026, 11, 20),
        reminder: 0,
      );
      expect(fullDays.start, DateTime.utc(2026, 11, 18, 21));
      expect(fullDays.end, DateTime.utc(2026, 11, 20, 21));
      expect(fullDays.exclusiveAllDayEnd, DateTime.utc(2026, 11, 21));
      expect(fullDays.isPast(DateTime.utc(2026, 11, 20, 20, 59, 59)), false);
      expect(fullDays.isPast(DateTime.utc(2026, 11, 20, 21)), true);
      expect(fullDays.notification?.target, DateTime.utc(2026, 11, 19, 6));
      expect(fullDays.notification?.expires, DateTime.utc(2026, 11, 19, 21));
      expect(
        () => _fixture(minute: null, through: DateTime.utc(2026, 11, 18)),
        throwsFormatException,
      );
      expect(
        () => _fixture(minute: null, endMinute: 10),
        throwsFormatException,
      );
      expect(() => _fixture(minute: null, reminder: 15), throwsFormatException);
    },
  );

  test(
    'private book reloads manual details, sorts by EAT, and deletes by stable ID',
    () async {
      final storage = MemoryCampusStorage();
      final book = await CampusEventBook.load(storage);
      addTearDown(book.dispose);
      final timed = _fixture(reminder: 15);
      final earlier = CampusEvent(
        id: '00000000000000000000000000000000',
        title: 'Yesterday (dummy)',
        kind: CampusEventKind.deadline,
        day: DateTime.utc(2026, 11, 18),
        minute: 1,
        dateChecked: true,
      );
      await book.save(timed);
      await book.save(earlier);
      final reopened = await CampusEventBook.load(storage);
      addTearDown(reopened.dispose);
      expect(reopened.listAt(now, past: false).single.toJson(), timed.toJson());
      expect(
        reopened.listAt(now, past: true).single.status,
        'Manual · date checked by you',
      );
      expect(campusDayOf(now), DateTime.utc(2026, 11, 18));
      await reopened.remove(timed.id);
      final afterDelete = await CampusEventBook.load(storage);
      addTearDown(afterDelete.dispose);
      expect(afterDelete.find(timed.id), isNull);
      expect(afterDelete.events.single.id, earlier.id);
    },
  );

  test('an unknown or unreadable book is not silently overwritten', () async {
    for (final raw in ['{', '{"version":2,"items":[]}']) {
      final storage = MemoryCampusStorage(snapshot: raw);
      final book = await CampusEventBook.load(storage);
      addTearDown(book.dispose);
      expect(book.available, false);
      await expectLater(book.save(_fixture()), throwsStateError);
      expect(storage.snapshot, raw);
    }
  });

  test(
    'iCalendar uses UTC timed values, stable UID, CRLF and safe UTF-8 folding',
    () {
      final unicode = List.filled(25, '🚀').join();
      final timed = _fixture(
        title: 'Drill, setup; $unicode\nBEGIN:VALARM',
        through: DateTime.utc(2026, 11, 19),
        endMinute: 40,
        reminder: 15,
      );
      final file = exportCampusEvent(timed, now);
      final lines = file.split('\r\n');
      expect(lines.last, '');
      expect(
        lines.every(
          (line) => utf8.encode(line).length <= 75 && !line.contains('\n'),
        ),
        true,
      );
      final unfolded = file.replaceAll('\r\n ', '').split('\r\n');
      expect(
        unfolded,
        containsAll([
          'UID:$testEventId@studydesk.local',
          'DTSTAMP:20261118T205959Z',
          'DTSTART:20261118T211000Z',
          'DTEND:20261118T214000Z',
          'SUMMARY:Drill\\, setup\\; $unicode\\nBEGIN:VALARM',
          r'LOCATION:Test venue\; room \\2',
        ]),
      );
      expect(unfolded, isNot(contains('BEGIN:VALARM')));
      expect(file, isNot(contains('Private notes')));
      expect(file, isNot(contains('example.test')));
      expect(file, isNot(contains('Manual example')));
      final edit = exportCampusEvent(_fixture(title: 'Edited name'), now);
      expect(edit, contains('UID:$testEventId@studydesk.local\r\n'));
      expect(edit, isNot(contains('DTEND')));
    },
  );

  test(
    'calendar draft and .ics keep all-day values as dates, not EAT midnight instants',
    () {
      final multi = _fixture(minute: null, through: DateTime.utc(2026, 11, 20));
      final single = _fixture(minute: null);
      expect(calendarDraft(multi), {
        'title': multi.title,
        'venue': multi.venue,
        'allDay': true,
        'begin': DateTime.utc(2026, 11, 19).millisecondsSinceEpoch,
        'end': DateTime.utc(2026, 11, 21).millisecondsSinceEpoch,
      });
      expect(
        exportCampusEvent(multi, now),
        contains(
          'DTSTART;VALUE=DATE:20261119\r\nDTEND;VALUE=DATE:20261121\r\n',
        ),
      );
      expect(
        exportCampusEvent(single, now),
        contains('DTEND;VALUE=DATE:20261120\r\n'),
      );
      final timed = _fixture();
      expect(
        calendarDraft(timed)['begin'],
        DateTime.utc(2026, 11, 18, 21, 10).millisecondsSinceEpoch,
      );
      expect(calendarDraft(timed)['end'], isNull);
    },
  );

  test(
    'Android calendar bridge reports launch, not save, and strips private fields',
    () async {
      const channel = MethodChannel('tz.altraware.studydesk/campus_events');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'addToCalendar');
        expect(
          (call.arguments as Map).keys,
          unorderedEquals(['title', 'venue', 'begin', 'end', 'allDay']),
        );
        return false; // No installed editor accepted the draft.
      });
      expect(await const AndroidCampusPlatform().openEditor(_fixture()), false);
    },
  );
}
