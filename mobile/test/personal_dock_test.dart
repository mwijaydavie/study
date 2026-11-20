import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studydesk/app/theme/personal_yellow_theme.dart';
import 'package:studydesk/core/widgets/personal_glass_nav_dock.dart';
import 'package:studydesk/design.dart';

void main() {
  testWidgets(
    'width budget keeps all five targets inside narrow and wide safe areas during morphs',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final selected = ValueNotifier(PersonalTab.home);
      addTearDown(selected.dispose);
      var opened = 0;
      var settings = 0;
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      for (final size in const [
        Size(360, 740),
        Size(320, 640),
        Size(275, 600),
        Size(185, 500),
        Size(844, 390),
        Size(1024, 768),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            theme: deskTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(bottom: 23),
                textScaler: TextScaler.linear(size.width > 1000 ? 1 : 1.8),
              ),
              child: child!,
            ),
            home: AmbientSolarBackdrop(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                extendBody: true,
                bottomNavigationBar: ValueListenableBuilder(
                  valueListenable: selected,
                  builder: (context, tab, _) => PersonalGlassNavDock(
                    currentTab: tab,
                    onTabSelected: (next) => selected.value = next,
                    onAiPressed: () => opened++,
                    onAiSettings: () => settings++,
                  ),
                ),
              ),
            ),
          ),
        );
        // Start each new selection before the last width interpolation settles.
        for (final tab in [
          PersonalTab.materials,
          PersonalTab.settings,
          PersonalTab.plan,
          PersonalTab.home,
        ]) {
          await tester.tap(find.byKey(ValueKey('nav-${tab.name}')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          expect(selected.value, tab);
          expect(tester.takeException(), isNull);
        }
        await tester.pump(const Duration(milliseconds: 360));
        for (final name in ['home', 'plan', 'materials', 'settings', 'ai']) {
          final rect = tester.getRect(find.byKey(ValueKey('nav-$name')));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(size.height - 23));
          expect(rect.width, greaterThanOrEqualTo(47.99));
          expect(rect.height, greaterThanOrEqualTo(47.99));
        }
        expect(find.bySemanticsLabel('Materials'), findsOneWidget);
        expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('nav-ai')));
      expect(opened, 1);
      await tester.longPress(find.byKey(const Key('nav-ai')));
      expect(opened, 1);
      expect(settings, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'reduced motion rests the orb and heavy feedback belongs to its hold action',
    (tester) async {
      final haptics = <Object?>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate')
          haptics.add(call.arguments);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      var held = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: PersonalGlassNavDock(
              currentTab: PersonalTab.home,
              onTabSelected: (_) {},
              onAiPressed: () {},
              onAiSettings: () => held = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, false);
      await tester.longPress(find.byKey(const Key('nav-ai')));
      await tester.pumpAndSettle();
      expect(held, true);
      expect(
        haptics
            .where((type) => type == 'HapticFeedbackType.heavyImpact')
            .length,
        1,
      );
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
}
