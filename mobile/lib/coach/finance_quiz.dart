import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class FinanceSource {
  const FinanceSource._(this.id, this.title, this.file, this.pageCount);
  final String id, title, file;
  final int pageCount;
}

class FinanceQuestion {
  const FinanceQuestion._({
    required this.id,
    required this.source,
    required this.pages,
    required this.prompt,
    required this.choices,
    required this.answer,
    required this.explanation,
  });

  final String id, prompt, explanation;
  final FinanceSource source;
  final List<int> pages;
  final List<String> choices;
  final int answer;

  String get citation =>
      '${source.file} · PDF ${pages.length == 1 ? 'p.' : 'pp.'} ${pages.join(', ')}';
}

/// Authored practice, not model output. Each answer is tied to the PDF pages
/// used for it. Load separately so a bad quiz bundle cannot block the timetable.
class FinanceQuizBank {
  const FinanceQuizBank._(this.sources, this.questions);

  final Map<String, FinanceSource> sources;
  final List<FinanceQuestion> questions;

  static Future<FinanceQuizBank> load(AssetBundle bundle) async =>
      FinanceQuizBank.decode(
        await bundle.loadString('assets/data/finance-quiz.json'),
      );

  factory FinanceQuizBank.decode(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1)
      throw const FormatException('Unsupported quiz data');
    final sources = <String, FinanceSource>{};
    for (final item in data['sources'] as List<dynamic>) {
      final id = item['id'] as String;
      final count = item['pageCount'] as int;
      if (sources.containsKey(id) || count < 1) {
        throw const FormatException('Invalid quiz source');
      }
      sources[id] = FinanceSource._(
        id,
        item['title'] as String,
        item['file'] as String,
        count,
      );
    }
    final seen = <String>{};
    final questions = <FinanceQuestion>[];
    for (final item in data['questions'] as List<dynamic>) {
      final id = item['id'] as String;
      final source = sources[item['source']];
      final pages = List<int>.from(item['pages'] as List);
      final choices = List<String>.from(item['choices'] as List);
      final answer = item['answer'] as int;
      if (!seen.add(id) ||
          source == null ||
          pages.isEmpty ||
          pages.any((page) => page < 1 || page > source.pageCount) ||
          choices.length < 2 ||
          choices.toSet().length != choices.length ||
          answer < 0 ||
          answer >= choices.length) {
        throw const FormatException('Invalid question or PDF reference');
      }
      questions.add(
        FinanceQuestion._(
          id: id,
          source: source,
          pages: List.unmodifiable(pages),
          prompt: item['prompt'] as String,
          choices: List.unmodifiable(choices),
          answer: answer,
          explanation: item['explanation'] as String,
        ),
      );
    }
    if (questions.isEmpty) throw const FormatException('Empty quiz');
    return FinanceQuizBank._(
      Map.unmodifiable(sources),
      List.unmodifiable(questions),
    );
  }

  List<FinanceQuestion> practice({String? sourceId, Random? random}) {
    final picker = random ?? Random();
    final buckets = [
      for (final id in sources.keys)
        if (sourceId == null || sourceId == id)
          questions.where((question) => question.source.id == id).toList()
            ..shuffle(picker),
    ]..shuffle(picker);
    final selected = <FinanceQuestion>[];
    // Take turns across selected sources so the mixed quiz covers both PDFs.
    while (selected.length < 5 && buckets.any((bucket) => bucket.isNotEmpty)) {
      for (final bucket in buckets) {
        if (bucket.isNotEmpty && selected.length < 5)
          selected.add(bucket.removeLast());
      }
    }
    return List.unmodifiable(selected);
  }
}
