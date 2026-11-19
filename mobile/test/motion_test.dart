import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studydesk/design.dart';
import 'package:studydesk/main.dart';
import 'package:studydesk/study_data.dart';
import 'package:studydesk/ui/desk_launch.dart';
import 'package:studydesk/ui/desk_motion.dart';
import 'package:studydesk/workspace.dart';

const _opening = 'Opening your offline workspace…';
const _selection = 'HapticFeedbackType.selectionClick';
const _confirm = 'HapticFeedbackType.lightImpact';

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the launch handoff does not hold up the ready workspace', (
    tester,
  ) async {
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(),
        home: ValueListenableBuilder<bool>(
          valueListenable: ready,
          builder: (context, loaded, _) => DeskLaunchStage(
            ready: loaded
                ? Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => presses++,
                        child: const Text('Open timetable'),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
    expect(find.text(_opening), findsOneWidget);
    ready.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // The previous frame is still fading, but it can't intercept input.
    expect(find.text(_opening), findsOneWidget);
    await tester.tap(find.text('Open timetable'));
    expect(presses, 1);
    await tester.pumpAndSettle();
    expect(find.text(_opening), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion skips launch, section and sheet animation', (
    tester,
  ) async {
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: deskTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ValueListenableBuilder<bool>(
          valueListenable: ready,
          builder: (context, loaded, _) => DeskLaunchStage(
            ready: loaded
                ? const DeskReveal(child: Text('Ready timetable'))
                : null,
          ),
        ),
      ),
    );
    expect(find.text(_opening), findsOneWidget);
    ready.value = true;
    await tester.pump();
    expect(find.text(_opening), findsNothing);
    final content = find.text('Ready timetable');
    final opacity = find.ancestor(of: content, matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(
      DeskMotion.sheetOf(tester.element(content)),
      AnimationStyle.noAnimation,
    );
    expect(tester.takeException(), isNull);
  });

  late StudyData data;
  setUpAll(() async {
    data = await StudyData.load(rootBundle);
  });

  testWidgets(
    'one native haptic per changed selection or checked task, none on launch or Back',
    (tester) async {
      final calls = <Object?>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final workspace = Workspace(null);
      addTearDown(workspace.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: deskTheme(),
          home: DeskHome(
            data: data,
            workspace: workspace,
            now: () => DateTime.utc(2026, 11, 19, 5),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await _tap(tester, find.text('Week'));
      await _tap(tester, find.text('Week'));
      await _tap(tester, find.text('Day'));
      await _tap(tester, find.text('Mon'));
      await _tap(tester, find.text('Mon'));
      expect(calls, [_selection, _selection, _selection]);

      await _tap(tester, find.text('Study plan'));
      await _tap(tester, find.text('Study plan'));
      expect(find.text('Class schedule'), findsNothing);
      final task = find.byKey(const ValueKey('done-ooad'));
      await tester.ensureVisible(task);
      await tester.tap(task);
      await tester.pump();
      final progress = find.byType(LinearProgressIndicator);
      expect(
        tester.widget<LinearProgressIndicator>(progress).value,
        lessThan(1 / 6),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<LinearProgressIndicator>(progress).value, 1 / 6);
      expect(calls, [_selection, _selection, _selection, _selection, _confirm]);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Class schedule'), findsOneWidget);
      expect(calls, hasLength(5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
}
