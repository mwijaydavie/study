import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../study_data.dart';

class StudyDay {
  const StudyDay._({
    this.minutesByCourse = const {},
    this.answered = 0,
    this.correct = 0,
  });
  final Map<String, int> minutesByCourse;
  final int answered, correct;

  int get totalMinutes => minutesByCourse.values.fold(0, (a, b) => a + b);
  bool get isEmpty => minutesByCourse.isEmpty && answered == 0;

  Map<String, Object> get _json => {
    'minutes': minutesByCourse,
    'answered': answered,
    'correct': correct,
  };
}

/// Records only what the owner enters and aggregate practice scores. No passive
/// activity monitoring, documents, messages, or network requests are involved.
class StudyJournal extends ChangeNotifier {
  StudyJournal(this._preferences) : _canSave = _preferences != null {
    _restore();
  }

  static const _key = 'studydesk.native.study_journal.v1';
  static const _maxDays = 90;
  static const maxMinutes = 24 * 60;
  static const _maxAnswers = 10000;
  static final _coursePattern = RegExp(r'^[A-Z0-9]{2,12}$');
  final SharedPreferences? _preferences;
  final _days = <String, StudyDay>{};
  Future<void> _writes = Future.value();
  bool _disposed = false;
  bool _unreadable = false;
  bool _canSave;

  bool get canSave => _canSave;
  bool get unreadable => _unreadable;
  bool get hasHistory => _days.isNotEmpty || _unreadable;
  String _keyAt(DateTime instant) => campusDayKey(campusDayOf(instant));
  StudyDay at(DateTime instant) => _days[_keyAt(instant)] ?? const StudyDay._();
  List<MapEntry<String, StudyDay>> recent({int limit = 7}) {
    final dates = _days.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final date in dates.take(limit)) MapEntry(date, _days[date]!)];
  }

  void _restore() {
    try {
      final raw = _preferences?.getString(_key);
      if (raw == null) return;
      if (raw.length > 100000)
        throw const FormatException('Oversized study log');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final days = data['days'] as Map<String, dynamic>;
      if (data['version'] != 1 || days.length > _maxDays) {
        throw const FormatException('Unsupported study log');
      }
      final restored = <String, StudyDay>{};
      for (final entry in days.entries) {
        final value = entry.value as Map<String, dynamic>;
        final minutes = Map<String, int>.from(value['minutes'] as Map);
        final answered = value['answered'] as int;
        final correct = value['correct'] as int;
        final day = StudyDay._(
          minutesByCourse: Map.unmodifiable(minutes),
          answered: answered,
          correct: correct,
        );
        if (parseCampusDay(entry.key) == null ||
            minutes.entries.any(
              (item) =>
                  !_coursePattern.hasMatch(item.key) ||
                  item.value < 1 ||
                  item.value > maxMinutes,
            ) ||
            day.totalMinutes > maxMinutes ||
            answered < 0 ||
            answered > _maxAnswers ||
            correct < 0 ||
            correct > answered) {
          throw const FormatException('Invalid study log entry');
        }
        if (!day.isEmpty) restored[entry.key] = day;
      }
      _days.addAll(restored);
    } catch (_) {
      // Don't erase an unreadable snapshot by saving over it. The UI offers an
      // explicit reset, and the current visit can still use an in-memory log.
      _unreadable = true;
      _canSave = false;
    }
  }

  Future<bool> setMinutes(DateTime instant, String course, int minutes) async {
    if (_disposed ||
        !_coursePattern.hasMatch(course) ||
        minutes < 0 ||
        minutes > maxMinutes)
      return false;
    final old = at(instant);
    final byCourse = Map<String, int>.of(old.minutesByCourse);
    if (minutes == 0) {
      byCourse.remove(course);
    } else {
      byCourse[course] = minutes;
    }
    final updated = StudyDay._(
      minutesByCourse: Map.unmodifiable(byCourse),
      answered: old.answered,
      correct: old.correct,
    );
    if (updated.totalMinutes > maxMinutes) return false;
    await _update(instant, updated);
    return true;
  }

  Future<void> recordAnswer(DateTime instant, {required bool correct}) async {
    final old = at(instant);
    if (_disposed || old.answered >= _maxAnswers) return;
    await _update(
      instant,
      StudyDay._(
        minutesByCourse: old.minutesByCourse,
        answered: old.answered + 1,
        correct: old.correct + (correct ? 1 : 0),
      ),
    );
  }

  Future<void> _update(DateTime instant, StudyDay day) {
    final key = _keyAt(instant);
    if (day.isEmpty) {
      _days.remove(key);
    } else {
      _days[key] = day;
    }
    if (_days.length > _maxDays) {
      final dates = _days.keys.toList()..sort();
      for (final date in dates.take(_days.length - _maxDays)) {
        _days.remove(date);
      }
    }
    notifyListeners();
    return _persist();
  }

  Future<void> clear() {
    if (_disposed) return Future.value();
    _days.clear();
    _unreadable = false;
    notifyListeners();
    return _persist();
  }

  Future<void> _persist() {
    final prefs = _preferences;
    if (prefs == null || _unreadable) return Future.value();
    final snapshot = jsonEncode({
      'version': 1,
      'days': _days.map((key, day) => MapEntry(key, day._json)),
    });
    _writes = _writes.then((_) async {
      var saved = false;
      try {
        saved = await prefs.setString(_key, snapshot);
      } catch (_) {
        // Keep the current view usable if device storage fails.
      }
      if (!_disposed && _canSave != saved) {
        _canSave = saved;
        notifyListeners();
      }
    });
    return _writes;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
