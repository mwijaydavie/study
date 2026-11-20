import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coach/assistant_preferences.dart';
import 'coach/study_journal.dart';
import 'study_data.dart';

/// Personal settings, checklist and a local study log never change the bundled
/// school timetable.
class Workspace extends ChangeNotifier {
  Workspace(this._preferences)
    : studyJournal = StudyJournal(_preferences),
      assistant = AssistantPreferences(_preferences) {
    final settings = _read(_settingsKey);
    use24Hour = settings['use24Hour'] != false;
    defaultView = settings['view'] == 'week'
        ? ScheduleView.week
        : ScheduleView.day;
    final progress = _read(_progressKey);
    final week = progress['week'];
    _weekKey = week is String ? week : null;
    final stored = progress['done'];
    if (stored is List) _done = stored.whereType<String>().toSet();
    canSave = _preferences != null;
  }

  static const _settingsKey = 'studydesk.native.settings.v1';
  static const _progressKey = 'studydesk.native.checklist.v1';
  final SharedPreferences? _preferences;
  final StudyJournal studyJournal;
  final AssistantPreferences assistant;
  bool _disposed = false;
  bool canSave = false;
  bool use24Hour = true;
  ScheduleView defaultView = ScheduleView.day;
  ScheduleView? _viewOverride;
  String? _weekKey;
  Set<String> _done = <String>{};

  ScheduleView get view => _viewOverride ?? defaultView;
  Set<String> doneFor(String week) =>
      week == _weekKey ? Set.unmodifiable(_done) : const <String>{};

  Map<String, dynamic> _read(String key) {
    try {
      final value = _preferences?.getString(key);
      final parsed = value == null ? null : jsonDecode(value);
      return parsed is Map<String, dynamic> ? parsed : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _save(String key, Map<String, dynamic> value) async {
    final prefs = _preferences;
    if (prefs == null) return;
    var saved = false;
    try {
      saved = await prefs.setString(key, jsonEncode(value));
    } catch (_) {
      // Continue in memory if the OS storage is temporarily unavailable.
    }
    if (!_disposed && canSave != saved) {
      canSave = saved;
      notifyListeners();
    }
  }

  Future<void> _saveSettings() =>
      _save(_settingsKey, {'use24Hour': use24Hour, 'view': defaultView.name});

  void setView(ScheduleView next) {
    _viewOverride = next;
    notifyListeners();
  }

  Future<void> setDefaultView(ScheduleView next) {
    _viewOverride = null;
    defaultView = next;
    notifyListeners();
    return _saveSettings();
  }

  Future<void> setTimeFormat(bool enabled) {
    use24Hour = enabled;
    notifyListeners();
    return _saveSettings();
  }

  Future<void> toggleTask(String week, String id) {
    if (week != _weekKey) {
      _weekKey = week;
      _done = <String>{};
    }
    if (!_done.add(id)) _done.remove(id);
    notifyListeners();
    return _saveProgress();
  }

  Future<void> clearWeek(String week) {
    if (_weekKey != week) return Future.value();
    _done.clear();
    notifyListeners();
    return _saveProgress();
  }

  Future<void> _saveProgress() => _save(_progressKey, {
    'week': _weekKey,
    'done': _done.toList(growable: false),
  });

  @override
  void dispose() {
    _disposed = true;
    studyJournal.dispose();
    assistant.dispose();
    super.dispose();
  }
}
