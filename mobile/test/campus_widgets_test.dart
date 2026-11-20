import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studydesk/campus/campus_calendar.dart';
import 'package:studydesk/campus/campus_events.dart';
import 'package:studydesk/design.dart';
import 'package:studydesk/main.dart';
import 'package:studydesk/pages/campus_events_page.dart';
import 'package:studydesk/reminders/reminder_plan.dart';
import 'package:studydesk/reminders/reminders.dart';
import 'package:studydesk/study_data.dart';
import 'package:studydesk/workspace.dart';

import 'support/static_desk_motion.dart';

import 'support/memory_campus_storage.dart';
import 'support/memory_reminder_platform.dart';

class _Calendar implements DeviceCalendar {
  int opens = 0;
  bool launchable = false;
  CampusEvent? draft;

  @override
  Future<bool> openEditor(CampusEvent event) async {
    opens++;
    draft = event;
    return launchable;
  }

  @override
  Future<bool> openSource(Uri uri) async => false;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

DateTime _now() => DateTime.utc(2026, 11, 18, 23, 30);

CampusEvent _event() => CampusEvent(
  id: '0123456789abcdef0123456789abcdef',
  title: 'Workshop (test fixture)',
  kind: CampusEventKind.workshop,
  day: DateTime.utc(2026, 11, 19),
  minute: 9 * 60,
  reminder: 15,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StudyData data;
  setUpAll(() async {
    data = await StudyData.load(rootBundle);
  });

  testWidgets(
    'Android Settings opens Campus events; add, edit, and delete without a network',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final storage = MemoryCampusStorage();
      final book = await CampusEventBook.load(storage);
      final phone = MemoryReminderPlatform();
      final model = ReminderController(
        plan: ClassReminderPlan(data),
        platform: phone,
        campusEvents: book,
        now: _now,
      );
      final workspace = Workspace(null);
      addTearDown(workspace.dispose);
      addTearDown(book.dispose);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: deskTheme(),
          builder: staticDeskMotion,
          home: DeskHome(
            data: data,
            workspace: workspace,
            reminders: model,
            now: _now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('nav-settings')));
      await _tap(tester, find.byKey(const Key('campus-events-settings')));
      await _tap(tester, find.byKey(const Key('add-campus-event')));
      final input = find.widgetWithText(TextFormField, 'Event title');
      final save = find.byKey(const Key('save-campus-event'));
      await tester.enterText(input, 'My test deadline');
      await _tap(tester, save);
      expect(find.textContaining('Choose a start date'), findsOneWidget);
      await _tap(tester, find.text('All day'));
      await _tap(tester, find.byKey(const Key('event-start-date')));
      await _tap(tester, find.text('OK'));
      await _tap(tester, find.byKey(const Key('campus-reminder-choice')));
      await _tap(tester, find.text('09:00 EAT on the first day').last);
      await _tap(tester, save);
      final item = book.events.single;
      expect(item.allDay, true);
      expect(item.day, DateTime.utc(2026, 11, 19));
      expect(phone.permissionRequests, 1);
      expect(phone.requests.containsKey(item.alertKey), true);
      await _tap(tester, find.text('My test deadline'));
      expect(find.text('Manual · unconfirmed'), findsOneWidget);
      expect(
        find.text('Preference: 09:00 EAT on the first day'),
        findsOneWidget,
      );
      expect(find.textContaining('Pending on Android'), findsOneWidget);

      await _tap(tester, find.text('Edit event'));
      await tester.enterText(input, 'Deadline renamed');
      await _tap(tester, find.byKey(const Key('campus-reminder-choice')));
      await _tap(tester, find.text('Off').last);
      await _tap(tester, save);
      expect(find.text('Deadline renamed'), findsOneWidget);
      expect(find.text('Preference: Off'), findsOneWidget);
      expect(book.events.single.id, item.id);
      expect(phone.requests, isEmpty);

      await _tap(tester, find.text('Delete event'));
      await _tap(tester, find.text('Cancel'));
      expect(book.events, hasLength(1));
      await _tap(tester, find.text('Delete event'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Delete event'));
      expect(book.events, isEmpty);
      final reloaded = await CampusEventBook.load(storage);
      addTearDown(reloaded.dispose);
      expect(reloaded.events, isEmpty);
      await _tap(tester, find.text('Past'));
      expect(find.text('No past events saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'calendar handoff is confirmed, can be canceled, and never claims save',
    (tester) async {
      final storage = MemoryCampusStorage();
      final book = await CampusEventBook.load(storage);
      final event = _event();
      final phone = MemoryReminderPlatform()
        ..access = NotificationAccess.denied;
      final model = ReminderController(
        plan: ClassReminderPlan(data),
        platform: phone,
        campusEvents: book,
        now: _now,
      );
      final calendar = _Calendar();
      addTearDown(book.dispose);
      addTearDown(model.dispose);
      await model.saveEvent(event);
      await tester.pumpWidget(
        MaterialApp(
          theme: deskTheme(),
          home: CampusEventDetail(
            eventId: event.id,
            book: book,
            reminders: model,
            use24Hour: true,
            calendar: calendar,
          ),
        ),
      );
      expect(find.text('Preference: 15 minutes before'), findsOneWidget);
      expect(
        find.textContaining('Android notifications blocked'),
        findsOneWidget,
      );
      final action = find.text('Add to device calendar');
      await _tap(tester, action);
      expect(calendar.opens, 0);
      await _tap(tester, find.text('Cancel'));
      expect(calendar.opens, 0);
      await _tap(tester, action);
      await _tap(tester, find.text('Open Calendar'));
      expect(calendar.opens, 1);
      expect(
        find.textContaining('No Calendar editor was found'),
        findsOneWidget,
      );

      calendar.launchable = true;
      await _tap(tester, action);
      await _tap(tester, find.text('Open Calendar'));
      expect(calendar.draft?.id, event.id);
      expect(
        find.textContaining('StudyDesk does not know whether you saved'),
        findsOneWidget,
      );
      expect(book.events.single.id, event.id);
      expect(phone.requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cold event taps open details; stale taps leave navigation alone',
    (tester) async {
      final book = await CampusEventBook.load(MemoryCampusStorage());
      final phone = MemoryReminderPlatform();
      final model = ReminderController(
        plan: ClassReminderPlan(data),
        platform: phone,
        campusEvents: book,
        now: _now,
      );
      final workspace = Workspace(null);
      addTearDown(workspace.dispose);
      addTearDown(book.dispose);
      addTearDown(model.dispose);
      final event = _event();
      await model.saveEvent(event);
      phone.tap(ReminderTap.event(event.id, event.revision));
      await tester.pumpWidget(
        MaterialApp(
          theme: deskTheme(),
          builder: staticDeskMotion,
          home: DeskHome(
            data: data,
            workspace: workspace,
            reminders: model,
            now: _now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Campus event'), findsOneWidget);
      expect(find.text(event.title), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      phone.tap(ReminderTap.event(event.id, 'old revision'));
      await tester.pumpAndSettle();
      expect(find.text(event.title), findsNothing);
      expect(find.byKey(const Key('campus-events-settings')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
