import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studydesk/coach/finance_quiz.dart';
import 'package:studydesk/coach/study_journal.dart';
import 'package:studydesk/design.dart';
import 'package:studydesk/main.dart';
import 'package:studydesk/pages/finance_quiz_page.dart';
import 'package:studydesk/study_data.dart';
import 'package:studydesk/workspace.dart';

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

const _quizAsset = 'assets/data/finance-quiz.json';

class _UnreadableQuizBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => key == _quizAsset
      ? Future.error(FlutterError('Missing quiz pack'))
      : rootBundle.load(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StudyData data;
  late FinanceQuizBank bank;
  final morning = DateTime.utc(2026, 11, 19, 6);

  setUpAll(() async {
    data = await StudyData.load(rootBundle);
    bank = data.financeQuiz!;
  });

  test('a missing quiz pack leaves the offline semester available', () async {
    final withoutQuiz = await StudyData.load(_UnreadableQuizBundle());
    expect(withoutQuiz.financeQuiz, isNull);
    expect(withoutQuiz.sessions, isNotEmpty);
    expect(withoutQuiz.guides, contains('finance-function'));
  });

  test(
    'FN200 practice alternates sources and rejects invalid PDF references',
    () async {
      expect(bank.sources.values.map((source) => source.pageCount), [39, 8]);
      expect(bank.questions, hasLength(12));
      final mixed = bank.practice(random: Random(7));
      expect(mixed, hasLength(5));
      expect(mixed.map((question) => question.source.id).toSet(), {
        'function',
        'instruments',
      });
      expect(mixed.map((question) => question.id).toSet(), hasLength(5));
      expect(
        bank
            .practice(sourceId: 'instruments')
            .every((q) => q.source.id == 'instruments'),
        true,
      );
      final broken =
          jsonDecode(await rootBundle.loadString(_quizAsset))
              as Map<String, dynamic>;
      broken['questions'][0]['pages'] = [40];
      expect(
        () => FinanceQuizBank.decode(jsonEncode(broken)),
        throwsFormatException,
      );
    },
  );

  test(
    'private study log restores edits and answer counts across EAT midnight',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final journal = StudyJournal(prefs);
      addTearDown(journal.dispose);
      final before = DateTime.utc(2026, 11, 18, 20, 59, 59);
      final after = before.add(const Duration(seconds: 1));
      expect(await journal.setMinutes(before, 'FN200', 35), true);
      expect(await journal.setMinutes(before, 'FN200', 30), true);
      expect(await journal.setMinutes(before, 'ST119', 1411), false);
      await journal.recordAnswer(before, correct: true);
      await journal.recordAnswer(after, correct: false);
      expect(await journal.setMinutes(after, 'IS237', 20), true);

      final restored = StudyJournal(prefs);
      addTearDown(restored.dispose);
      expect(restored.at(before).minutesByCourse, {'FN200': 30});
      expect(restored.at(before).correct, 1);
      expect(restored.at(after).minutesByCourse, {'IS237': 20});
      expect(restored.at(after).answered, 1);
      expect(restored.at(after).correct, 0);
      expect(restored.recent().map((day) => day.key), [
        '2026-11-19',
        '2026-11-18',
      ]);
      expect(await restored.setMinutes(after, 'IS237', 0), true);
      expect(restored.at(after).totalMinutes, 0);
      await restored.clear();
      final cleared = StudyJournal(prefs);
      addTearDown(cleared.dispose);
      expect(cleared.recent(), isEmpty);
    },
  );

  test(
    'unreadable study history is not overwritten until it is cleared',
    () async {
      const key = 'studydesk.native.study_journal.v1';
      SharedPreferences.setMockInitialValues({key: '???'});
      final prefs = await SharedPreferences.getInstance();
      final journal = StudyJournal(prefs);
      addTearDown(journal.dispose);
      expect(journal.unreadable, true);
      await journal.setMinutes(morning, 'FN200', 5);
      expect(prefs.getString(key), '???');
      await journal.clear();
      expect(journal.unreadable, false);
      expect(journal.canSave, true);
    },
  );

  testWidgets(
    'plan opens the private daily log and a source-filtered, cited quiz',
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
          home: DeskHome(data: data, workspace: workspace, now: () => morning),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Study plan'));
      await _tap(tester, find.byKey(const Key('open-study-coach')));
      expect(find.text('Dakika 0'), findsOneWidget);
      final input = find.byKey(const Key('coach-minutes'));
      await tester.ensureVisible(input);
      await tester.enterText(input, '25');
      await _tap(tester, find.byKey(const Key('save-coach-study')));
      expect(find.text('Dakika 25'), findsOneWidget);
      expect(workspace.studyJournal.at(morning).minutesByCourse, {'FN200': 25});

      expect(find.text('Financial instruments'), findsOneWidget);
      await _tap(tester, find.text('Financial instruments'));
      await _tap(tester, find.byKey(const Key('start-fn200-quiz')));
      final questions = tester
          .widget<FinanceQuizPage>(find.byType(FinanceQuizPage))
          .questions;
      expect(questions, hasLength(5));
      expect(
        questions.every((question) => question.source.id == 'instruments'),
        true,
      );
      for (var i = 0; i < questions.length; i++) {
        final question = questions[i];
        final option = i == 0
            ? (question.answer + 1) % question.choices.length
            : question.answer;
        await _tap(tester, find.byKey(ValueKey('coach-option-$option')));
        await _tap(tester, find.byKey(const Key('check-coach-answer')));
        expect(find.text(question.citation), findsOneWidget);
        await _tap(tester, find.byKey(const Key('next-coach-question')));
      }
      expect(find.textContaining('4 / 5 correct'), findsOneWidget);
      expect(find.text('Rudia haya'), findsOneWidget);
      await _tap(tester, find.text('Back to Study Coach'));
      expect(find.text('Quiz leo: 4 / 5 sahihi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
