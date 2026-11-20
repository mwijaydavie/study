import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class DeskMotion {
  static const quick = Duration(milliseconds: 160);
  static const section = Duration(milliseconds: 210);
  static const launch = Duration(milliseconds: 260);

  static Duration durationOf(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  static AnimationStyle sheetOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(duration: launch, reverseDuration: section);
}

/// Reveal only the active content. There is no outgoing interactive copy, and
/// the child is not rebuilt on every animation frame.
class DeskReveal extends StatelessWidget {
  const DeskReveal({
    super.key,
    required this.child,
    this.duration = DeskMotion.section,
    this.distance = 8,
  });

  final Widget child;
  final Duration duration;
  final double distance;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: reduceMotion ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        final remaining = reduceMotion ? 0.0 : 1 - value;
        return Opacity(
          opacity: 1 - remaining * .28,
          child: Transform.translate(
            offset: Offset(0, remaining * distance),
            child: child,
          ),
        );
      },
    );
  }
}

/// Native touch feedback is best-effort. It never blocks navigation or a save,
/// and asks the OS for a touch effect rather than raw vibration.
abstract final class DeskHaptics {
  static void selection() => unawaited(_play(HapticFeedback.selectionClick));

  static void confirm() => unawaited(_play(HapticFeedback.lightImpact));

  static Future<void> _play(Future<void> Function() effect) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await effect();
    } on MissingPluginException {
      // No local touch feedback service.
    } on PlatformException {
      // An unavailable effect must not interrupt the user's action.
    }
  }
}
