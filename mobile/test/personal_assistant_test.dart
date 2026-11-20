import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studydesk/coach/assistant_preferences.dart';
import 'package:studydesk/coach/desk_answers.dart';
import 'package:studydesk/design.dart';
import 'package:studydesk/main.dart';
import 'package:studydesk/study_data.dart';
import 'package:studydesk/workspace.dart';

import 'support/static_desk_motion.dart';

Future<void> _tap(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: .15);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StudyData data;
  final now = DateTime.utc(2026, 11, 18, 23, 30); // Thursday in Dar es Salaam.
  setUpAll(() async {
    data = await StudyData.load(rootBundle);
  });

  test(
    'offline answers follow EAT and the bundled sources, not arbitrary questions',
    () async {
      final workspace = Workspace(null);
      addTearDown(workspace.dispose);
      DeskAnswer ask(
        String value, {
        AssistantTone tone = AssistantTone.friendly,
        DateTime? time,
      }) => answerOnDevice(
        intent: deskIntent(value),
        data: data,
        journal: workspace.studyJournal,
        now: time ?? now,
        use24Hour: true,
        tone: tone,
      );
      expect(ask('Leo?').title, 'Thu, 19 Nov 2026 · EAT');
      expect(ask('Leo').lines, contains('08:00–09:30 · IS237 · Computer Lab'));
      expect(ask('Kesho').title, 'Fri, 20 Nov 2026 · EAT');
      expect(
        ask('Leo', time: DateTime.utc(2026, 11, 21)).detail.toLowerCase(),
        contains('no classes'),
      );
      expect(ask('Next class').detail, contains('Cheki, Mwijay'));
      expect(
        ask('Next class', tone: AssistantTone.brief).detail,
        isNot(contains('Mwijay')),
      );
      await workspace.studyJournal.setMinutes(now, 'FN200', 25);
      expect(ask('Umesoma nini leo?').lines, ['FN200 · 25 minutes']);
      expect(
        ask('Risk and return').lines.single,
        contains('Risk and Return Analysis.pdf'),
      );
      expect(ask('FN200').detail, contains('18 authored questions'));
      expect(ask('Is there an exam tomorrow?').title, 'Quick capture');
    },
  );

  test(
    'tone and explicit pins persist; turning memory off blocks new notes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final model = AssistantPreferences(prefs);
      addTearDown(model.dispose);
      expect(await model.pin('no consent'), PinResult.off);
      await model.setTone(AssistantTone.brief);
      await model.setMemory(true);
      expect(await model.pin('  Review expected return  '), PinResult.saved);
      expect(await model.pin('Review expected return'), PinResult.duplicate);
      expect(await model.pin('  '), PinResult.invalid);
      for (var i = 1; i < AssistantPreferences.maxPins; i++) {
        expect(await model.pin('Note $i'), PinResult.saved);
      }
      expect(await model.pin('Too many'), PinResult.full);
      await model.setMemory(false);
      final restored = AssistantPreferences(prefs);
      addTearDown(restored.dispose);
      expect(restored.tone, AssistantTone.brief);
      expect(restored.memory, false);
      expect(restored.pins.last, 'Review expected return');
      expect(await restored.pin('no new notes'), PinResult.off);
      await restored.unpin('Note 1');
      expect(restored.pins, isNot(contains('Note 1')));
      await restored.clearPins();
      final reopened = AssistantPreferences(prefs);
      addTearDown(reopened.dispose);
      expect(reopened.pins, isEmpty);
    },
  );

  testWidgets(
    'Home capture, AI Settings hold, local pin and FN200 guide connect to real screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final workspace = Workspace(null);
      addTearDown(workspace.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: deskTheme(),
          builder: staticDeskMotion,
          home: DeskHome(data: data, workspace: workspace, now: () => now),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mwijay.'), findsOneWidget);
      await tester.longPress(find.byKey(const Key('nav-ai')));
      await tester.pumpAndSettle();
      expect(find.text('AI Settings'), findsOneWidget);
      expect(find.text('Offline Study Coach'), findsOneWidget);
      await _tap(tester, find.text('Brief'));
      await _tap(tester, find.byKey(const Key('assistant-memory')));
      expect(workspace.assistant.memory, true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      const note = 'Recheck the weighted average exercise';
      await tester.enterText(find.byKey(const Key('home-capture')), note);
      await _tap(tester, find.byKey(const Key('home-send')));
      expect(find.text('Personal AI'), findsOneWidget);
      expect(workspace.assistant.pins, isEmpty);
      await _tap(tester, find.byKey(const Key('pin-capture')));
      expect(workspace.assistant.pins, [note]);
      await _tap(tester, find.widgetWithText(ActionChip, 'Leo'));
      expect(find.text('Thu, 19 Nov 2026 · EAT'), findsOneWidget);
      expect(find.text('08:00–09:30 · IS237 · Computer Lab'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(note), findsOneWidget);
      await _tap(tester, find.byTooltip('Unpin note'));
      expect(workspace.assistant.pins, isEmpty);

      await _tap(tester, find.byKey(const Key('home-fn200')));
      await _tap(tester, find.text('Risk and return analysis'));
      expect(find.textContaining('Risk and Return Analysis.pdf'), findsWidgets);
      expect(find.textContaining('= 12%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
