import 'dart:async';

import 'package:flutter/material.dart';

import '../coach/finance_quiz.dart';
import '../coach/study_journal.dart';
import '../design.dart';
import '../study_data.dart';
import '../ui/desk_motion.dart';

class FinanceQuizPage extends StatefulWidget {
  FinanceQuizPage({
    super.key,
    required this.questions,
    required this.journal,
    required this.now,
  }) : assert(questions.isNotEmpty);

  final List<FinanceQuestion> questions;
  final StudyJournal journal;
  final DateTime Function() now;

  @override
  State<FinanceQuizPage> createState() => _FinanceQuizPageState();
}

class _FinanceQuizPageState extends State<FinanceQuizPage> {
  int _index = 0;
  int? _selection;
  bool _checked = false;
  bool _finished = false;
  final _review = <FinanceQuestion>[];
  FinanceQuestion get _question => widget.questions[_index];

  void _check() {
    if (_selection == null || _checked) return;
    final correct = _selection == _question.answer;
    setState(() {
      _checked = true;
      if (!correct) _review.add(_question);
    });
    if (correct) DeskHaptics.confirm();
    unawaited(widget.journal.recordAnswer(widget.now(), correct: correct));
  }

  void _next() => setState(() {
    if (_index + 1 == widget.questions.length) {
      _finished = true;
    } else {
      _index++;
      _selection = null;
      _checked = false;
    }
  });

  Widget _choice(int index) {
    final picked = index == _selection;
    final right = _checked && index == _question.answer;
    final wrong = _checked && picked && !right;
    final tone = right
        ? green
        : wrong
        ? peach
        : violet;
    return Semantics(
      selected: picked,
      child: OutlinedButton(
        key: ValueKey('coach-option-$index'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          side: BorderSide(color: picked || right ? tone.ink : DeskColors.line),
          backgroundColor: picked ? tone.surface : DeskColors.white,
          disabledBackgroundColor: picked || right
              ? tone.surface
              : DeskColors.white,
          disabledForegroundColor: DeskColors.ink,
        ),
        onPressed: _checked
            ? null
            : () {
                if (picked) return;
                DeskHaptics.selection();
                setState(() => _selection = index);
              },
        child: Row(
          children: [
            Icon(
              right
                  ? Icons.check_circle_outline
                  : wrong
                  ? Icons.cancel_outlined
                  : picked
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 19,
              color: picked || right ? tone.ink : DeskColors.muted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _question.choices[index],
                style: deskType(13, height: 1.32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _result() => [
    DeskHero(
      title: 'Umemaliza!',
      caption: 'FN200 · OFFLINE PRACTICE',
      subtitle:
          '${widget.questions.length - _review.length} / ${widget.questions.length} correct. Review the source before your next round.',
      meta: 'Practice counts stay on this phone',
      icon: Icons.fact_check_outlined,
      background: green.surface,
      accent: green.ink,
    ),
    if (_review.isNotEmpty) ...[
      const SizedBox(height: 12),
      const SectionTitle('Rudia haya', 'Read the cited pages, then try again.'),
      for (final item in _review) ...[
        const SizedBox(height: 8),
        DeskCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.prompt, style: deskType(13, weight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(
                item.choices[item.answer],
                style: deskType(13, color: green.ink),
              ),
              const SizedBox(height: 5),
              Text(item.citation, style: deskType(11, color: DeskColors.muted)),
            ],
          ),
        ),
      ],
    ],
    const SizedBox(height: 13),
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Back to Study Coach'),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final correct = _selection == _question.answer;
    return Scaffold(
      appBar: AppBar(title: const Text('FN200 practice')),
      body: SafeArea(
        top: false,
        child: DeskPage(
          key: ValueKey((_index, _finished)),
          clock: CampusClock.at(widget.now()),
          children: _finished
              ? _result()
              : [
                  DeskReveal(
                    child: DeskCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MetaLabel(
                            Icons.psychology_alt_outlined,
                            'SWALI ${_index + 1} / ${widget.questions.length} · ${_question.source.title}',
                            color: violet.ink,
                          ),
                          const SizedBox(height: 10),
                          Semantics(
                            header: true,
                            child: Text(
                              _question.prompt,
                              style: deskType(
                                21,
                                weight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (
                            var index = 0;
                            index < _question.choices.length;
                            index++
                          ) ...[_choice(index), const SizedBox(height: 7)],
                          if (!_checked)
                            FilledButton(
                              key: const Key('check-coach-answer'),
                              onPressed: _selection == null ? null : _check,
                              child: const Text('Check answer'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_checked) ...[
                    const SizedBox(height: 10),
                    DeskReveal(
                      duration: DeskMotion.quick,
                      child: DeskCard(
                        color: correct ? green.surface : peach.surface,
                        border: correct ? green.surface : peach.surface,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                correct
                                    ? 'Sahihi!'
                                    : 'Jibu sahihi: ${_question.choices[_question.answer]}',
                                style: deskType(14, weight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _question.explanation,
                              style: deskType(13, height: 1.45),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _question.citation,
                              style: deskType(11, color: DeskColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    FilledButton(
                      key: const Key('next-coach-question'),
                      onPressed: _next,
                      child: Text(
                        _index + 1 == widget.questions.length
                            ? 'Finish quiz'
                            : 'Next question',
                      ),
                    ),
                  ],
                ],
        ),
      ),
    );
  }
}
