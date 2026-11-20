import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studydesk/design.dart';
import 'package:studydesk/main.dart';
import 'package:studydesk/reminders/reminder_plan.dart';
import 'package:studydesk/reminders/reminders.dart';
import 'package:studydesk/study_data.dart';
import 'package:studydesk/workspace.dart';

import 'support/memory_reminder_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StudyData data;
  setUpAll(() async {
    data = await StudyData.load(rootBundle);
  });

  Future<Workspace> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    ReminderController? reminders,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workspace = Workspace(null);
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: DeskHome(
          data: data,
          workspace: workspace,
          reminders: reminders,
          now: () => DateTime.parse('2026-11-18T23:30:00Z'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return workspace;
  }

  Future<void> next(WidgetTester tester, Finder finder) async {
    await Scrollable.ensureVisible(tester.element(finder), alignment: .15);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Thursday, class details and Settings use the same local data', (
    tester,
  ) async {
    final workspace = await open(tester);
    await next(tester, find.byKey(const Key('nav-plan')));
    expect(find.text('Thursday'), findsOneWidget);
    expect(find.text('Principles of Finance'), findsOneWidget);
    expect(find.text('OFFLINE READY'), findsOneWidget);
    await next(tester, find.text('Details'));
    expect(find.text('Thursday · 08:00–09:30 EAT'), findsOneWidget);
    expect(find.text('Mr. Gambadu'), findsWidgets);
    await next(tester, find.byTooltip('Close'));
    await next(tester, find.byKey(const Key('nav-settings')));
    await next(tester, find.byKey(const Key('use-24-hour')));
    await next(tester, find.byKey(const Key('default-week-view')));
    expect(workspace.use24Hour, false);
    expect(workspace.defaultView, ScheduleView.week);
    await next(tester, find.byKey(const Key('nav-plan')));
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('8:00 AM'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('study task and searchable Materials work from the bottom bar', (
    tester,
  ) async {
    final workspace = await open(tester);
    await next(tester, find.byKey(const Key('nav-plan')));
    await next(tester, find.byKey(const Key('plan-checklist')));
    await next(tester, find.byKey(const ValueKey('done-ooad')));
    expect(find.text('1 / 6 done'), findsOneWidget);
    await next(tester, find.byKey(const Key('nav-settings')));
    await next(tester, find.text('Clear this week’s checklist'));
    await next(tester, find.text('Clear checklist'));
    expect(workspace.doneFor('2026-11-16'), isEmpty);
    await next(tester, find.byKey(const Key('nav-materials')));
    await tester.enterText(find.byType(TextField), 'subnetting');
    await tester.pumpAndSettle();
    await next(tester, find.text('Unit II — Subnetting'));
    expect(find.textContaining('Course code not confirmed'), findsWidgets);
    await next(tester, find.byTooltip('Close'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('compact phone still shows four destinations with larger text', (
    tester,
  ) async {
    await open(tester, size: const Size(320, 740), textScale: 1.6);
    for (final tab in ['home', 'plan', 'materials', 'settings', 'ai']) {
      expect(find.byKey(ValueKey('nav-$tab')), findsOneWidget);
    }
    await next(tester, find.byKey(const Key('nav-settings')));
    expect(find.text('Offline & privacy'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Your day at a glance'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  ReminderController android(MemoryReminderPlatform phone) {
    final reminders = ReminderController(
      plan: ClassReminderPlan(data),
      platform: phone,
      now: () => DateTime.parse('2026-11-18T23:30:00Z'),
    );
    addTearDown(reminders.dispose);
    return reminders;
  }

  testWidgets(
    'date confirmation opts in, then Settings shows and cancels the pending reminder',
    (tester) async {
      final phone = MemoryReminderPlatform();
      final reminders = android(phone);
      await open(tester, reminders: reminders);
      expect(phone.permissionRequests, 0);
      await next(tester, find.byKey(const Key('nav-plan')));
      await next(tester, find.text('Details'));
      await next(tester, find.byKey(const Key('remind-from-class-details')));
      expect(find.text('Target: Thu, 19 Nov 2026 · 07:45 EAT'), findsOneWidget);
      expect(phone.permissionRequests, 0);
      await next(tester, find.byKey(const Key('confirm-class-reminder')));
      expect(phone.permissionRequests, 1);
      expect(phone.requests.keys.single, 'class:thu-is237:2026-11-19');
      await next(tester, find.byKey(const Key('nav-settings')));
      await next(tester, find.byKey(const Key('class-reminders-settings')));
      expect(find.text('Pending reminders'), findsOneWidget);
      expect(
        find.text('Target: Thu, 19 Nov 2026 · 07:45 EAT · 15 min before'),
        findsOneWidget,
      );
      await next(tester, find.text('Remove'));
      expect(phone.requests, isEmpty);
      expect(find.text('Nothing scheduled yet.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('cold and warm notification taps open dated class details', (
    tester,
  ) async {
    final phone = MemoryReminderPlatform();
    final reminders = android(phone);
    final session = reminders.plan.classes.firstWhere(
      (item) => item.id == 'thu-is237',
    );
    final choice = reminders.plan.choices(session, reminders.now()).first;
    final request = reminders.plan.create(choice, 15, reminders.now())!;
    final tap = ReminderTap(
      request.sessionId!,
      request.dayKey!,
      request.revision!,
    );
    const when = 'Thu, 19 Nov 2026 · 08:00–09:30 EAT';
    phone.tap(tap);
    await open(tester, reminders: reminders);
    expect(find.text(when), findsOneWidget);
    await next(tester, find.byTooltip('Close'));
    await next(tester, find.byKey(const Key('nav-settings')));
    await next(tester, find.byKey(const Key('class-reminders-settings')));
    phone.tap(tap);
    await tester.pumpAndSettle();
    expect(find.text(when), findsOneWidget);
    expect(find.byKey(const Key('personal-dock')), findsOneWidget);
    expect(phone.permissionRequests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
