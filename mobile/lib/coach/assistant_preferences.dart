import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AssistantTone { friendly, brief }

enum PinResult { saved, sessionOnly, off, invalid, duplicate, full }

/// Only explicitly pinned notes are retained. Questions and responses are
/// transient, and this store is never read by an online service.
class AssistantPreferences extends ChangeNotifier {
  AssistantPreferences(this._prefs) : _canSave = _prefs != null {
    try {
      final raw = _prefs?.getString(_key);
      if (raw == null) return;
      if (raw.length > 10000) throw const FormatException('Large pin store');
      final stored = jsonDecode(raw) as Map<String, dynamic>;
      final pins = List<String>.from(stored['pins'] as List);
      if (stored['version'] != 1 ||
          pins.length > maxPins ||
          pins.any((pin) => !_valid(pin))) {
        throw const FormatException('Invalid pin store');
      }
      _pins.addAll(pins);
      _tone = stored['tone'] == 'brief'
          ? AssistantTone.brief
          : AssistantTone.friendly;
      _memory = stored['memory'] == true;
    } catch (_) {
      // Keep the last on-disk copy until the owner explicitly clears it.
      _unreadable = true;
      _canSave = false;
    }
  }

  static const _key = 'studydesk.native.assistant.v1';
  static const maxPins = 12;
  static const noteLimit = 180;
  final SharedPreferences? _prefs;
  final _pins = <String>[];
  AssistantTone _tone = AssistantTone.friendly;
  bool _memory = false;
  bool _unreadable = false;
  bool _canSave;
  bool _disposed = false;
  Future<bool> _writes = Future.value(true);

  List<String> get pins => List.unmodifiable(_pins);
  AssistantTone get tone => _tone;
  bool get memory => _memory;
  bool get canSave => _canSave;
  bool get unreadable => _unreadable;

  static bool _valid(String text) =>
      text.trim().isNotEmpty && text.length <= noteLimit;

  Future<void> setTone(AssistantTone tone) async {
    if (_disposed || tone == _tone) return;
    _tone = tone;
    notifyListeners();
    await _save();
  }

  Future<void> setMemory(bool value) async {
    if (_disposed || value == _memory) return;
    _memory = value;
    notifyListeners();
    await _save();
  }

  Future<PinResult> pin(String input) async {
    if (_disposed || !_memory) return PinResult.off;
    final text = input.trim();
    if (!_valid(text)) return PinResult.invalid;
    if (_pins.contains(text)) return PinResult.duplicate;
    if (_pins.length >= maxPins) return PinResult.full;
    _pins.insert(0, text);
    notifyListeners();
    return await _save() ? PinResult.saved : PinResult.sessionOnly;
  }

  Future<void> unpin(String text) async {
    if (_disposed || !_pins.remove(text)) return;
    notifyListeners();
    await _save();
  }

  Future<void> clearPins() async {
    if (_disposed) return;
    _pins.clear();
    _unreadable = false;
    notifyListeners();
    await _save();
  }

  Future<bool> _save() {
    final prefs = _prefs;
    if (prefs == null || _unreadable) return Future.value(false);
    final payload = jsonEncode({
      'version': 1,
      'tone': _tone.name,
      'memory': _memory,
      'pins': _pins,
    });
    _writes = _writes.then((_) async {
      var saved = false;
      try {
        saved = await prefs.setString(_key, payload);
      } catch (_) {
        // Stay usable in memory if device storage fails.
      }
      if (!_disposed && saved != _canSave) {
        _canSave = saved;
        notifyListeners();
      }
      return saved;
    });
    return _writes;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
