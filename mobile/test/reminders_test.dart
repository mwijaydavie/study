import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studydesk/reminders/reminder_plan.dart';
import 'package:studydesk/reminders/reminders.dart';
import 'package:studydesk/study_data.dart';

import 'support/memory_reminder_platform.dart';

class _RevisedBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final source = await rootBundle.loadString(key);
    if (!key.endsWith('/semester.json')) return source;
    final data = jsonDecode(source) as Map<String, dynamic>;
    final sessions = (data['sessions'] as List).cast<Map<String, dynamic>>();
    sessions.singleWhere((item) => item['id'] == 'thu-is237')['venue'] =
        'Test room';
    return jsonEncode(data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.parse(
    '2026-11-18T15:50:00-08:00',
  ); // Thursday 02:50 EAT.
  late ClassReminderPlan plan;
  late Session classOnThursday;
  late ClassOccurrence chosen;
  setUpAll(() async {
    plan = ClassReminderPlan(await StudyData.load(rootBundle));
    classOnThursday = plan.classes.singleWhere(
      (session) => session.id == 'thu-is237',
    );
    chosen = plan.choices(classOnThursday, now).first;
  });

  ReminderController controller(
    MemoryReminderPlatform platform, {
    ClassReminderPlan? revision,
  }) {
    final model = ReminderController(
      plan: revision ?? plan,
      platform: platform,
      now: () => now,
    );
    addTearDown(model.dispose);
    return model;
  }

  test(
    'EAT midnight determines the date, and the Android target is a real UTC instant',
    () {
      expect(
        campusDayKey(campusDayOf(DateTime.parse('2026-11-18T20:59:59Z'))),
        '2026-11-18',
      );
      expect(
        campusDayKey(campusDayOf(DateTime.parse('2026-11-18T21:00:00Z'))),
        '2026-11-19',
      );
      expect(campusDayKey(chosen.campusDay), '2026-11-19');
      final item = plan.create(chosen, 15, now)!;
      expect(item.key, 'class:thu-is237:2026-11-19');
      expect(item.expires, DateTime.utc(2026, 11, 19, 5));
      expect(item.target, DateTime.utc(2026, 11, 19, 4, 45));
      expect(
        campusStamp(item.target, use24Hour: true),
        'Thu, 19 Nov 2026 · 07:45 EAT',
      );
      expect(
        ReminderRequest.fromPlatform(item.toPlatform()).target,
        item.target,
      );
    },
  );

  test(
    'does not schedule passed times, unmatched weekdays, Chapel or unbounded dates',
    () {
      expect(plan.occurrence('thu-is237', '2026-11-18'), isNull);
      expect(plan.occurrence('thu-is237', '2026-02-30'), isNull);
      expect(plan.occurrence('wed-chapel', '2026-11-25'), isNull);
      final late = DateTime.parse('2026-11-19T04:45:00Z');
      expect(chosen.availableLeads(late), [5]);
      expect(plan.create(chosen, 15, late), isNull);
      expect(plan.create(chosen, 10, now), isNull);
      final outside = plan.occurrence('thu-is237', '2026-12-03')!;
      expect(plan.create(outside, 15, now), isNull);
      expect(plan.choices(classOnThursday, now).length, 2);
    },
  );

  test(
    'off at launch, asks once on opt-in, redirection after denial',
    () async {
      final phone = MemoryReminderPlatform()
        ..afterRequest = NotificationAccess.denied;
      final reminders = controller(phone);
      await reminders.refresh();
      expect(reminders.statusLabel, startsWith('Off'));
      expect(phone.permissionRequests, 0);
      final deniedMessage = await reminders.setClassReminder(chosen, 15);
      expect(deniedMessage, contains('denied'));
      await reminders.sendTest(delayed: true);
      expect(phone.permissionRequests, 1);
      expect(phone.requests, isEmpty);
      await reminders.openSettings();
      expect(phone.settingsOpened, 1);
      phone.access = NotificationAccess.allowed;
      await reminders.refresh();
      await reminders.setClassReminder(chosen, 15);
      expect(phone.permissionRequests, 1);
      expect(reminders.pending.single.sessionId, 'thu-is237');
      phone.access = NotificationAccess.blocked;
      await reminders.refresh();
      expect(reminders.statusLabel, contains('blocked'));
    },
  );

  test(
    'lead time changes replace only the same occurrence; remove and turn off',
    () async {
      final phone = MemoryReminderPlatform();
      final reminders = controller(phone);
      await reminders.setClassReminder(chosen, 15);
      await reminders.setClassReminder(chosen, 30);
      expect(phone.requests.entries.single.value.lead, 30);
      expect(
        reminders.pending.single.target,
        DateTime.utc(2026, 11, 19, 4, 30),
      );
      final firstKey = reminders.pending.single.key;
      await reminders.setClassReminder(
        plan.choices(classOnThursday, now).last,
        15,
      );
      expect(reminders.pending, hasLength(2));
      await reminders.remove(firstKey);
      expect(reminders.pending, hasLength(1));
      expect(reminders.pending.single.dayKey, '2026-11-26');
      await reminders.sendTest(delayed: false);
      await reminders.sendTest(delayed: true);
      expect(phone.testNotifications, 1);
      expect(reminders.pending.first.isTest, true);
      expect(
        reminders.pending.first.target,
        now.add(const Duration(minutes: 1)),
      );
      expect(phone.permissionRequests, 1);
      await reminders.removeAll();
      expect(phone.requests, isEmpty);
      expect(reminders.pending, isEmpty);
    },
  );

  test(
    'opening a revised timetable cancels changed occurrences, not unaffected ones',
    () async {
      final is237 = plan.create(chosen, 15, now)!;
      final finance = plan.classes.singleWhere(
        (item) => item.id == 'thu-fn200',
      );
      final fn200 = plan.create(plan.choices(finance, now).first, 15, now)!;
      final phone = MemoryReminderPlatform()
        ..access = NotificationAccess.allowed;
      phone.requests.addEntries([
        MapEntry(is237.key, is237),
        MapEntry(fn200.key, fn200),
      ]);
      final revised = ClassReminderPlan(await StudyData.load(_RevisedBundle()));
      final reminders = controller(phone, revision: revised);
      await reminders.refresh();
      expect(reminders.removedChangedClasses, true);
      expect(phone.requests.keys, [fn200.key]);
      expect(reminders.pending.single, fn200);
    },
  );

  test(
    'notification taps are consumed and only open a matching class date and revision',
    () async {
      final phone = MemoryReminderPlatform();
      final reminders = controller(phone);
      final request = plan.create(chosen, 15, now)!;
      phone.tap(
        ReminderTap(request.sessionId!, request.dayKey!, 'old revision'),
      );
      expect(await reminders.takeOpenedReminder(), isNull);
      phone.tap(
        ReminderTap(request.sessionId!, request.dayKey!, request.revision!),
      );
      final opened = (await reminders.takeOpenedReminder())?.classDate;
      expect(opened?.session, classOnThursday);
      expect(opened?.campusDay, chosen.campusDay);
      expect(await reminders.takeOpenedReminder(), isNull);
      expect(phone.permissionRequests, 0);
    },
  );

  test('missing Android bridge leaves offline data usable', () async {
    final reminders = controller(MemoryReminderPlatform()..missing = true);
    expect(await reminders.refresh(), contains('offline'));
    expect(reminders.access, NotificationAccess.unavailable);
    expect(plan.data.onDay(DateTime.thursday), hasLength(2));
  });
}
