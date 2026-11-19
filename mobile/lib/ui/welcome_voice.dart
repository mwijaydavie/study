import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WelcomeClip { karibu, mambo, welcome, inakuaje, tujipime }

abstract interface class WelcomePlayer {
  Future<bool> play(WelcomeClip clip);
  Future<void> stop();
}

class AndroidWelcomePlayer implements WelcomePlayer {
  const AndroidWelcomePlayer();
  static const _channel = MethodChannel('tz.altraware.studydesk/welcome_voice');

  @override
  Future<bool> play(WelcomeClip clip) async {
    try {
      return await _channel.invokeMethod<bool>('play', clip.name) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Some platforms do not have the native player.
    } on PlatformException {
      // Audio is optional and never affects the workspace.
    }
  }
}

/// One short local greeting per visit. A quick interruption (such as a system
/// overlay) is not a new visit; leaving the foreground stops the current clip.
class WelcomeVoice extends ChangeNotifier {
  WelcomeVoice(this._prefs, this._player) {
    try {
      _enabled = _prefs?.getBool(_enabledKey) ?? true;
      _next = (_prefs?.getInt(_nextKey) ?? 0) % WelcomeClip.values.length;
    } catch (_) {
      // Ignore incompatible settings; keep the app usable without storage.
    }
  }

  static const _enabledKey = 'studydesk.native.welcome_voice.enabled';
  static const _nextKey = 'studydesk.native.welcome_voice.next';
  static const minimumAway = Duration(seconds: 12);
  final SharedPreferences? _prefs;
  final WelcomePlayer _player;
  bool _enabled = true;
  bool _disposed = false;
  bool _ready = false;
  bool _opened = false;
  bool _requesting = false;
  int _next = 0;
  AppLifecycleState? _state;
  DateTime? _awaySince;

  bool get enabled => _enabled;

  void ready(AppLifecycleState? state, DateTime now) {
    if (_ready || _disposed) return;
    _ready = true;
    lifecycle(state ?? AppLifecycleState.resumed, now);
  }

  void lifecycle(AppLifecycleState state, DateTime now) {
    if (_disposed) return;
    final wasActive = _state == AppLifecycleState.resumed;
    _state = state;
    if (state == AppLifecycleState.resumed) {
      if (!_ready) return;
      final away = _awaySince;
      _awaySince = null;
      if (!_opened || (away != null && now.difference(away) >= minimumAway)) {
        _opened = true;
        if (_enabled) unawaited(_playNext());
      }
    } else {
      if (state == AppLifecycleState.hidden ||
          state == AppLifecycleState.paused) {
        _awaySince ??= now;
      }
      if (wasActive) unawaited(_player.stop());
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_disposed || _enabled == value) return;
    _enabled = value;
    notifyListeners();
    if (!value) unawaited(_player.stop());
    try {
      await _prefs?.setBool(_enabledKey, value);
    } catch (_) {
      // Stay enabled/disabled in this visit if the preference cannot be saved.
    }
  }

  /// A tap can preview the next clip even with automatic greetings off.
  Future<bool> preview() => _playNext();

  Future<bool> _playNext() async {
    if (_disposed ||
        !_ready ||
        _state != AppLifecycleState.resumed ||
        _requesting)
      return false;
    _requesting = true;
    try {
      final played = await _player.play(WelcomeClip.values[_next]);
      if (played) {
        _next = (_next + 1) % WelcomeClip.values.length;
        try {
          await _prefs?.setInt(_nextKey, _next);
        } catch (_) {
          // Rotation still works for the current app process.
        }
      }
      return played;
    } finally {
      _requesting = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_player.stop());
    super.dispose();
  }
}
