import '../study_data.dart';
import 'assistant_preferences.dart';
import 'study_journal.dart';

enum DeskIntent { today, tomorrow, nextClass, studyLog, finance, risk, unknown }

DeskIntent deskIntent(String input) => switch (input
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[?!.]+$'), '')
    .replaceAll(RegExp(r'\s+'), ' ')) {
  'leo' ||
  'today' ||
  'today’s plan' ||
  "today's plan" ||
  'plan today' => DeskIntent.today,
  'kesho' || 'tomorrow' || 'class tomorrow' => DeskIntent.tomorrow,
  'next' || 'next class' || 'darasa linalofuata' => DeskIntent.nextClass,
  'study log' ||
  'study progress' ||
  'umesoma nini leo' ||
  'nimesoma nini leo' => DeskIntent.studyLog,
  'fn200' || 'finance' || 'finance quiz' || 'quiz' => DeskIntent.finance,
  'risk and return' || 'risk and return analysis' => DeskIntent.risk,
  _ => DeskIntent.unknown,
};

typedef DeskAnswer = ({String title, String detail, List<String> lines});

/// A read-only lookup over the same EAT inputs shown on Home and in Plan.
/// No arbitrary text interpretation, guessing deadlines, or network calls.
DeskAnswer answerOnDevice({
  required DeskIntent intent,
  required StudyData data,
  required StudyJournal journal,
  required DateTime now,
  required bool use24Hour,
  required AssistantTone tone,
}) {
  final clock = CampusClock.at(now);
  final friendly = tone == AssistantTone.friendly;
  String sessionLabel(Session session) =>
      '${formatRange(session.start, session.end, use24Hour: use24Hour)} · '
      '${session.code ?? data.titleFor(session)} · ${session.venue}';

  switch (intent) {
    case DeskIntent.today:
    case DeskIntent.tomorrow:
      final date = campusDayOf(
        now,
      ).add(Duration(days: intent == DeskIntent.tomorrow ? 1 : 0));
      final classes = data.onDay(date.weekday);
      final study = data.blocks.where((block) => block.day == date.weekday);
      return (
        title: '${campusDayLabel(date)} · EAT',
        detail: classes.isEmpty
            ? (friendly
                  ? 'Mwijay, no classes are listed in the bundled draft for this day.'
                  : 'No classes listed in the bundled draft for this day.')
            : '${friendly ? 'Haya, Mwijay. ' : ''}From the bundled revised draft, page ${data.sourcePage}; verify changes with UAUT.',
        lines: [
          for (final session in classes) sessionLabel(session),
          for (final block in study)
            'Suggested study: ${formatRange(block.start, block.end, use24Hour: use24Hour)} · ${block.code} · ${block.title}',
        ],
      );
    case DeskIntent.nextClass:
      final upcoming = data.upcoming(clock);
      if (upcoming == null) {
        return (
          title: 'Up next',
          detail: 'No upcoming activity in the bundled draft.',
          lines: const [],
        );
      }
      return (
        title: upcoming.inProgress ? 'Happening now' : 'Up next',
        detail:
            '${friendly ? 'Cheki, Mwijay. ' : ''}${upcoming.dayLabel} · EAT · revised draft',
        lines: [sessionLabel(upcoming.session)],
      );
    case DeskIntent.studyLog:
      final day = journal.at(now);
      return (
        title: friendly ? 'Umesoma nini leo?' : 'Study log · today',
        detail:
            '${day.totalMinutes} minutes logged · ${day.correct}/${day.answered} quiz answers correct. EAT date; only what you entered.',
        lines: [
          for (final item in day.minutesByCourse.entries)
            '${item.key} · ${item.value} minutes',
        ],
      );
    case DeskIntent.finance:
      final count = data.financeQuiz?.questions.length ?? 0;
      return (
        title: 'FN200 revision',
        detail: count == 0
            ? 'Read a bundled guide; the quiz pack is unavailable.'
            : '$count authored questions with PDF citations. Choose a source in Study Coach.',
        lines: [
          for (final key in financeGuideKeys)
            if (data.guides[key] case final guide?) guide.title,
        ],
      );
    case DeskIntent.risk:
      final guide = data.guides['finance-risk-return'];
      return (
        title: 'Risk and return',
        detail: guide == null
            ? 'This guide is not available in the bundled library.'
            : 'Expected return = sum of probability × possible return. A weighted average is not a guarantee.',
        lines: [if (guide != null) guide.source],
      );
    case DeskIntent.unknown:
      return (
        title: 'Quick capture',
        detail:
            'No online model is connected. Try Leo, Kesho, Next class, Study log or FN200. You can also pin this as a private note.',
        lines: const [],
      );
  }
}
