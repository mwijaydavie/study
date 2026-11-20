import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studydesk/ui/welcome_voice.dart';

class _Player implements WelcomePlayer {
  final requests = <WelcomeClip>[];
  bool accept = true;
  int stops = 0;

  @override
  Future<bool> play(WelcomeClip clip) async {
    requests.add(clip);
    return accept;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 19, 6);

  test(
    'greets once on launch and a real return, not on quick overlays',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final player = _Player();
      final voice = WelcomeVoice(prefs, player);
      addTearDown(voice.dispose);
      voice.lifecycle(AppLifecycleState.resumed, now);
      expect(player.requests, isEmpty);
      voice.ready(AppLifecycleState.resumed, now);
      await _settle();
      voice.ready(AppLifecycleState.resumed, now);
      voice.lifecycle(AppLifecycleState.inactive, now);
      voice.lifecycle(
        AppLifecycleState.resumed,
        now.add(const Duration(seconds: 1)),
      );
      expect(player.requests, [WelcomeClip.karibu]);
      expect(player.stops, 1);
      voice.lifecycle(AppLifecycleState.hidden, now);
      voice.lifecycle(AppLifecycleState.paused, now);
      voice.lifecycle(
        AppLifecycleState.resumed,
        now.add(WelcomeVoice.minimumAway),
      );
      await _settle();
      expect(player.requests, [WelcomeClip.karibu, WelcomeClip.mambo]);

      final restartPlayer = _Player();
      final restarted = WelcomeVoice(prefs, restartPlayer);
      addTearDown(restarted.dispose);
      restarted.ready(AppLifecycleState.resumed, now);
      await _settle();
      expect(restartPlayer.requests, [WelcomeClip.welcome]);
    },
  );

  test(
    'mute persists; explicit previews respect availability and do not skip a rejected clip',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = WelcomeVoice(prefs, _Player());
      await first.setEnabled(false);
      first.dispose();
      final player = _Player()..accept = false;
      final voice = WelcomeVoice(prefs, player);
      addTearDown(voice.dispose);
      voice.ready(AppLifecycleState.resumed, now);
      await _settle();
      expect(player.requests, isEmpty);
      expect(voice.enabled, false);
      expect(await voice.preview(), false);
      player.accept = true;
      expect(await voice.preview(), true);
      expect(player.requests, [WelcomeClip.karibu, WelcomeClip.karibu]);
      voice.lifecycle(AppLifecycleState.paused, now);
      expect(await voice.preview(), false);
      expect(player.stops, 1);
    },
  );
}
