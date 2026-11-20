import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design.dart';
import 'desk_motion.dart';

/// Continue Android's branded launch surface while the bundled data opens.
/// Mount the workspace as soon as it's ready; the fade never gates input.
class DeskLaunchStage extends StatelessWidget {
  const DeskLaunchStage({super.key, this.ready, this.failed = false});

  final Widget? ready;
  final bool failed;

  static Widget _transition(Widget child, Animation<double> animation) =>
      _LaunchFade(animation: animation, child: child);

  static Widget _layout(Widget? current, List<Widget> outgoing) => Stack(
    fit: StackFit.expand,
    children: [
      for (final child in outgoing)
        IgnorePointer(
          key: child.key,
          child: ExcludeSemantics(child: child),
        ),
      if (current != null) current,
    ],
  );

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: deskSystemBars,
    child: ColoredBox(
      color: DeskColors.launchSurface,
      child: AnimatedSwitcher(
        duration: DeskMotion.durationOf(context, DeskMotion.launch),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: _transition,
        layoutBuilder: _layout,
        child: ready ?? _DeskSplash(failed: failed),
      ),
    ),
  );
}

class _LaunchFade extends StatelessWidget {
  const _LaunchFade({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: MediaQuery.disableAnimationsOf(context)
        ? kAlwaysCompleteAnimation
        : animation,
    child: child,
  );
}

class _DeskSplash extends StatelessWidget {
  const _DeskSplash({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/art/app-mark.png',
                  width: 96,
                  height: 96,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: DeskColors.gold,
                    child: SizedBox.square(
                      dimension: 96,
                      child: Icon(Icons.menu_book_outlined, size: 44),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              DeskReveal(
                duration: DeskMotion.quick,
                distance: 4,
                child: Column(
                  children: [
                    Semantics(
                      header: true,
                      child: Text.rich(
                        TextSpan(
                          text: 'StudyDesk',
                          style: deskType(
                            34,
                            weight: FontWeight.w800,
                            spacing: -1.5,
                            height: 1.12,
                          ),
                          children: const [
                            TextSpan(
                              text: '.',
                              style: TextStyle(color: Color(0xff865b10)),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        failed
                            ? 'Couldn’t load the bundled StudyDesk files. Rebuild with the matching offline assets.'
                            : 'Opening your offline workspace…',
                        textAlign: TextAlign.center,
                        style: deskType(
                          13,
                          color: DeskColors.muted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
