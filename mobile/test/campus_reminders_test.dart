import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studydesk/campus/campus_events.dart';
import 'package:studydesk/reminders/reminder_plan.dart';
import 'package:studydesk/reminders/reminders.dart';
import 'package:studydesk/study_data.dart';

import 'support/memory_campus_storage.dart';
import 'support/memory_reminder_platform.dart';

CampusEvent _event({
  int n = 1,
  int minute = 9 * 60,
  int? lead = 15,
  DateTime? day,
}) => CampusEvent(
  id: n.toRadixString(16).padLeft(32, '0'),
  title: 'Test seminar $n',
  kind: CampusEventKind.seminar,
  day: day ?? DateTime.utc(2026, 11, 19),
  minute: minute,
  reminder: lead,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ClassReminderPlan plan;
  late MemoryCampusStorage storage;
  late MemoryReminderPlatform phone;
  late CampusEventBook book;
  late ReminderController model;
  late DateTime now;

  setUpAll(() async {
    plan = ClassReminderPlan(await StudyData.load(rootBundle));
  });
  setUp(() async {
    now = DateTime.parse('2026-11-18T23:30:00Z');
    storage = MemoryCampusStorage();
    phone = MemoryReminderPlatform();
    book = await CampusEventBook.load(storage);
    model = ReminderController(
      plan: plan,
      platform: phone,
      campusEvents: book,
      now: () => now,
    );
  });
  tearDown(() {
    model.dispose();
    book.dispose();
  });

  test(
    'event off by default; permission denial saves preference but no pending alarm',
    () async {
      phone.afterRequest = NotificationAccess.denied;
      await model.refresh();
      expect((await model.saveEvent(_event(lead: null))).saved, true);
      expect(phone.permissionRequests, 0);
      final choice = _event();
      expect((await model.saveEvent(choice)).saved, true);
      expect(phone.permissionRequests, 1);
      expect(book.find(choice.id)?.reminder, 15);
      expect(model.pendingFor(choice), isNull);
      expect(phone.requests, isEmpty);
      await model.saveEvent(choice);
      expect(phone.permissionRequests, 1);

      await model.openSettings();
      expect(phone.settingsOpened, 1);
      phone.access = NotificationAccess.allowed;
      await model.refresh();
      expect(
        model.pendingFor(choice)?.target,
        DateTime.utc(2026, 11, 19, 5, 45),
      );
      expect(model.pending, isEmpty); // Only class/test reminders appear there.
      phone.access = NotificationAccess.blocked;
      await model.refresh();
      expect(model.pendingFor(choice), isNull);
      expect(book.find(choice.id)?.reminder, 15);
      expect(phone.permissionRequests, 1);
    },
  );

  test(
    'edit or delete cancels before durable write, then queues only the new target',
    () async {
      final first = _event();
      await model.saveEvent(first);
      final edited = _event(minute: 10 * 60, lead: 30);
      var seen = 0;
      storage.beforeWrite = () async {
        expect(
          phone.requests,
          isEmpty,
        ); // An old alert can't survive the successful write.
        expect(book.find(first.id), isNotNull);
        seen++;
      };
      expect((await model.saveEvent(edited)).saved, true);
      expect(
        phone.requests.values.single.target,
        DateTime.utc(2026, 11, 19, 6, 30),
      );
      expect(phone.requests.keys.single, first.alertKey);
      expect(model.pendingFor(first), isNull);
      expect((await model.saveEvent(_event(lead: null))).saved, true);
      expect(phone.requests, isEmpty);
      storage.beforeWrite = null;
      await model.saveEvent(edited);
      storage.beforeWrite = () async {
        expect(phone.requests, isEmpty);
        seen++;
      };
      expect((await model.deleteEvent(edited.id)).saved, true);
      expect(seen, 3);
      expect(book.events, isEmpty);
      await model.refresh();
      expect(phone.requests, isEmpty);
    },
  );

  test(
    'failed cancellation keeps the event; failed storage write never schedules the edit',
    () async {
      final first = _event();
      final edited = _event(minute: 11 * 60);
      await model.saveEvent(first);
      final oldDisk = storage.snapshot;
      phone.failCancel = true;
      expect((await model.deleteEvent(first.id)).saved, false);
      expect((await model.saveEvent(edited)).saved, false);
      expect(storage.snapshot, oldDisk);
      expect(phone.requests.values.single.revision, first.revision);

      phone.failCancel = false;
      storage.failWrites = true;
      expect((await model.saveEvent(edited)).saved, false);
      expect(book.find(first.id)?.revision, first.revision);
      expect(storage.snapshot, oldDisk);
      expect(phone.requests, isEmpty);
      expect(model.pendingFor(first), isNull);
      await model.refresh();
      expect(phone.requests.values.single.revision, first.revision);
    },
  );

  test('coalesces resume reconciliation without racing an event write', () async {
    final first = _event();
    await model.saveEvent(first);
    final begun = Completer<void>();
    final finish = Completer<void>();
    storage.beforeWrite = () {
      begun.complete();
      return finish.future;
    };
    final edited = _event(minute: 10 * 60);
    final inProgress = model.saveEvent(edited);
    await begun.future;
    expect(phone.requests, isEmpty);
    await model.refresh();
    expect((await model.deleteEvent(first.id)).saved, false);
    expect(phone.requests, isEmpty);
    finish.complete();
    expect((await inProgress).saved, true);
    // Drain the immediate fake bridge futures scheduled by the deferred refresh.
    await Future<void>.delayed(Duration.zero);
    expect(phone.requests.values.single.revision, edited.revision);
    expect(book.events.single.revision, edited.revision);
  });

  test(
    'a rejected or unarmed Android request is not shown as pending',
    () async {
      phone.failSchedule = true;
      final event = _event();
      expect((await model.saveEvent(event)).saved, true);
      expect(model.pendingFor(event), isNull);
      expect(book.find(event.id)?.reminder, 15);
      phone.failSchedule = false;
      phone.eventsArmed = false;
      await model.refresh();
      expect(phone.requests, contains(event.alertKey));
      expect(model.pendingFor(event), isNull);
      phone.eventsArmed = true;
      await model.refresh();
      expect(model.pendingFor(event)?.key, event.alertKey);
    },
  );

  test(
    'event horizon and capacity do not interfere with class schedules',
    () async {
      final distant = _event(n: 99, day: DateTime.utc(2028, 1, 1));
      final expired = _event(n: 100, day: DateTime.utc(2026, 11, 18));
      await model.saveEvent(distant);
      await model.saveEvent(expired);
      expect(phone.permissionRequests, 0);
      expect(phone.requests, isEmpty);

      final session = plan.classes.firstWhere((item) => item.id == 'thu-is237');
      final date = plan.choices(session, now).first;
      await model.setClassReminder(date, 15);
      for (var n = 1; n <= eventReminderCapacity; n++) {
        expect((await model.saveEvent(_event(n: n))).saved, true);
      }
      final overflow = _event(n: eventReminderCapacity + 1);
      expect((await model.saveEvent(overflow)).saved, true);
      expect(model.pendingFor(overflow), isNull);
      expect(phone.requests, hasLength(eventReminderCapacity + 1));
      expect(model.pending.single.sessionId, session.id);
      await model.removeAll();
      expect(phone.requests, hasLength(eventReminderCapacity));
      await model.deleteEvent(_event().id);
      await model.refresh();
      expect(model.pendingFor(overflow), isNotNull);
      expect(model.pendingFor(distant), isNull);
      expect(model.pendingFor(expired), isNull);
    },
  );

  test(
    'event taps reject old revisions and deleted entries without triggering writes',
    () async {
      final first = _event();
      await model.saveEvent(first);
      final edited = _event(minute: 9 * 60 + 5);
      await model.saveEvent(edited);
      phone.tap(ReminderTap.event(first.id, first.revision));
      expect(await model.takeOpenedReminder(), isNull);
      phone.tap(ReminderTap.event(edited.id, edited.revision));
      expect((await model.takeOpenedReminder())?.event?.id, edited.id);
      await model.deleteEvent(edited.id);
      phone.tap(ReminderTap.event(edited.id, edited.revision));
      expect(await model.takeOpenedReminder(), isNull);
      expect(phone.requests, isEmpty);
    },
  );
}
