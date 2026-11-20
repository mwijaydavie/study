import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../app/theme/personal_yellow_theme.dart';
import '../../design.dart';
import '../../ui/desk_motion.dart';

enum PersonalTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  plan('Plan', Icons.event_note_outlined, Icons.event_note_rounded),
  materials('Materials', Icons.folder_outlined, Icons.folder_copy_rounded),
  settings('Settings', Icons.tune_outlined, Icons.tune_rounded);

  const PersonalTab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon, activeIcon;
}

class PersonalGlassNavDock extends StatelessWidget {
  const PersonalGlassNavDock({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    required this.onAiPressed,
    required this.onAiSettings,
  });

  final PersonalTab currentTab;
  final ValueChanged<PersonalTab> onTabSelected;
  final VoidCallback onAiPressed, onAiSettings;

  static const _diameter = 62.0;
  static const _gap = 10.0;
  static const _inner = 6.0;
  static const _touch = 48.0;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = math.min(548.0, constraints.maxWidth);
          final edge = maxWidth >= 342 ? 16.0 : 6.0;
          final width = math.max(0.0, maxWidth - edge * 2);
          // At unusual split-window widths, put the orb above the pill rather
          // than shrinking the targets. Below one row's minimum, use two rows.
          final inline = width >= 4 * _touch + _inner * 2 + _diameter + _gap;
          final pill = SolarGlass(
            radius: 999,
            padding: const EdgeInsets.symmetric(
              horizontal: _inner,
              vertical: 7,
            ),
            child: _TabStrip(current: currentTab, onSelect: onTabSelected),
          );
          final orb = SizedBox.square(
            dimension: _diameter,
            child: SpringScaleTap(
              key: const Key('nav-ai'),
              label: 'AI Assistant',
              hint: 'Hold for AI Settings',
              scaleDown: .90,
              onTap: onAiPressed,
              onLongPress: onAiSettings,
              child: const _LivingSolarOrb(),
            ),
          );
          return Center(
            heightFactor: 1,
            child: SizedBox(
              width: width,
              child: inline
                  ? Row(
                      children: [
                        Expanded(child: pill),
                        const SizedBox(width: _gap),
                        orb,
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: orb,
                        ),
                        const SizedBox(height: 6),
                        pill,
                      ],
                    ),
            ),
          );
        },
      ),
    ),
  );
}

typedef _Weights = (double, double, double, double);

/// Use one interpolated width budget. Independent width animations can have a
/// different total on a rapid tab change or while a split window is resized.
class _WidthTween extends Tween<_Weights> {
  _WidthTween(_Weights target) : super(begin: target, end: target);

  @override
  _Weights lerp(double t) {
    final (a, b, c, d) = begin!;
    final (w, x, y, z) = end!;
    return (a + (w - a) * t, b + (x - b) * t, c + (y - c) * t, d + (z - d) * t);
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.current, required this.onSelect});
  final PersonalTab current;
  final ValueChanged<PersonalTab> onSelect;

  static const _labelSize = 12.5;
  static const _step = Duration(milliseconds: 320);
  static const _labelInset = 6.0;
  static const _iconSize = 21.0;

  @override
  Widget build(BuildContext context) {
    final motion = DeskMotion.durationOf(context, _step);
    final labelStyle = deskType(
      _labelSize,
      spacing: -.2,
      color: PersonalAppColors.inkObsidian,
    );
    final label = TextPainter(
      text: TextSpan(
        text: current.label,
        style: DefaultTextStyle.of(context).style.merge(labelStyle),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final labelWidth = label.width.ceilToDouble() + 1;
    label.dispose();
    final weights = switch (current) {
      PersonalTab.home => (1.0, 0.0, 0.0, 0.0),
      PersonalTab.plan => (0.0, 1.0, 0.0, 0.0),
      PersonalTab.materials => (0.0, 0.0, 1.0, 0.0),
      PersonalTab.settings => (0.0, 0.0, 0.0, 1.0),
    };

    Widget tile(PersonalTab tab, {required bool showLabel}) {
      final selected = tab == current;
      final caption = selected && showLabel
          ? Padding(
              padding: const EdgeInsetsDirectional.only(start: _labelInset),
              child: Text(
                tab.label,
                style: labelStyle,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
              ),
            )
          : const SizedBox.shrink();
      return SizedBox(
        height: PersonalGlassNavDock._touch,
        child: SpringScaleTap(
          key: ValueKey('nav-${tab.name}'),
          label: tab.label,
          selected: selected,
          feedbackOnTap: !selected,
          onTap: () => onSelect(tab),
          child: AnimatedContainer(
            duration: motion,
            curve: DeskMotion.solar,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: selected
                  ? RadialGradient(
                      center: const Alignment(-.55, -.2),
                      radius: 1.4,
                      colors: [
                        PersonalAppColors.solarYellowMain.withValues(
                          alpha: .56,
                        ),
                        PersonalAppColors.solarGlowSoft.withValues(alpha: .82),
                        PersonalAppColors.pureWhite.withValues(alpha: .94),
                      ],
                    )
                  : null,
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: _iconSize,
                  child: AnimatedSwitcher(
                    duration: DeskMotion.durationOf(
                      context,
                      const Duration(milliseconds: 200),
                    ),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: Icon(
                      selected ? tab.activeIcon : tab.icon,
                      key: ValueKey(selected),
                      size: _iconSize,
                      color: selected
                          ? PersonalAppColors.inkObsidian
                          : PersonalAppColors.inkMuted,
                    ),
                  ),
                ),
                Flexible(
                  child: ClipRect(
                    // Flutter 3.32 can re-dirty AnimatedSize during layout
                    // when its controller has a zero duration. Render the
                    // final caption directly with reduced motion enabled.
                    child: motion == Duration.zero
                        ? caption
                        : AnimatedSize(
                            duration: motion,
                            curve: DeskMotion.solar,
                            alignment: AlignmentDirectional.centerStart,
                            child: caption,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        if (width < 4 * PersonalGlassNavDock._touch) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < 2; row++)
                Row(
                  children: [
                    for (final tab in PersonalTab.values.skip(row * 2).take(2))
                      Expanded(child: tile(tab, showLabel: false)),
                  ],
                ),
            ],
          );
        }
        final extra = math.min(88.0, width - 4 * PersonalGlassNavDock._touch);
        final base = (width - extra) / 4;
        final showLabel =
            base + extra >= _iconSize + _labelInset + labelWidth + 16;
        return TweenAnimationBuilder<_Weights>(
          tween: _WidthTween(weights),
          duration: motion,
          curve: DeskMotion.solar,
          builder: (context, value, _) {
            // A live change to reduced motion snaps even mid-transition.
            final (a, b, c, _) = motion == Duration.zero ? weights : value;
            return Row(
              children: [
                for (final (tab, share) in [
                  (PersonalTab.home, a),
                  (PersonalTab.plan, b),
                  (PersonalTab.materials, c),
                ])
                  SizedBox(
                    width: base + extra * share,
                    child: tile(tab, showLabel: showLabel),
                  ),
                Expanded(
                  child: tile(PersonalTab.settings, showLabel: showLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Only the paint layer changes per tick. The accessible button and the rest
/// of the dock do not rebuild when the light shifts.
class _LivingSolarOrb extends StatefulWidget {
  const _LivingSolarOrb();

  @override
  State<_LivingSolarOrb> createState() => _LivingSolarOrbState();
}

class _LivingSolarOrbState extends State<_LivingSolarOrb>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _light;
  late final _SolarOrbPainter _painter;
  bool _motion = false;
  AppLifecycleState? _state;

  @override
  void initState() {
    super.initState();
    _light = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    _painter = _SolarOrbPainter(_light);
    _state = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion =
        !MediaQuery.disableAnimationsOf(context) && TickerMode.of(context);
    _update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _state = state;
    _update();
  }

  void _update() {
    final active =
        _motion && (_state == null || _state == AppLifecycleState.resumed);
    if (active && !_light.isAnimating) _light.repeat();
    if (!active && _light.isAnimating) _light.stop();
    if (!_motion && _light.value != 0) _light.value = 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: PersonalAppColors.solarAmberDeep.withValues(alpha: .32),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        key: const Key('solar-orb-paint'),
        painter: _painter,
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _SolarOrbPainter extends CustomPainter {
  _SolarOrbPainter(this.light) : super(repaint: light);
  final Animation<double> light;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2;
    final wave = (math.sin(light.value * 2 * math.pi) + 1) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-.34 + wave * .14, -.40 + wave * .12),
          radius: 1.05 + wave * .04,
          colors: const [
            PersonalAppColors.pureWhite,
            PersonalAppColors.activePillWash,
            PersonalAppColors.solarAmberDeep,
          ],
          stops: const [0, .55, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius - .7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0x55ffffff), Color(0xd9fff1b8)],
        ).createShader(rect),
    );
    _sparkle(canvas, center + const Offset(-2.5, 1), 10.5 + wave * .6);
    _sparkle(canvas, center + const Offset(10, -9), 3.4 + (1 - wave) * .6);
  }

  void _sparkle(Canvas canvas, Offset origin, double r) {
    final d = r * .16;
    final path = Path()
      ..moveTo(origin.dx, origin.dy - r)
      ..quadraticBezierTo(
        origin.dx + d,
        origin.dy - d,
        origin.dx + r,
        origin.dy,
      )
      ..quadraticBezierTo(
        origin.dx + d,
        origin.dy + d,
        origin.dx,
        origin.dy + r,
      )
      ..quadraticBezierTo(
        origin.dx - d,
        origin.dy + d,
        origin.dx - r,
        origin.dy,
      )
      ..quadraticBezierTo(
        origin.dx - d,
        origin.dy - d,
        origin.dx,
        origin.dy - r,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = PersonalAppColors.inkObsidian);
  }

  @override
  bool shouldRepaint(covariant _SolarOrbPainter oldDelegate) => false;
}

/// Preserve the hit target while animating its clipped visual child.
class SpringScaleTap extends StatefulWidget {
  const SpringScaleTap({
    super.key,
    required this.label,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.hint,
    this.selected,
    this.scaleDown = .93,
    this.feedbackOnTap = true,
  });
  final String label;
  final String? hint;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool? selected;
  final double scaleDown;
  final bool feedbackOnTap;

  @override
  State<SpringScaleTap> createState() => _SpringScaleTapState();
}

class _SpringScaleTapState extends State<SpringScaleTap>
    with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 360,
    damping: 22,
  );
  late final _scale = AnimationController(
    vsync: this,
    value: 1,
    lowerBound: .84,
    upperBound: 1.06,
  );
  bool _pressed = false;
  bool _focused = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced && _scale.value != 1) _scale.value = 1;
  }

  void _down(TapDownDetails details) {
    _pressed = true;
    if (widget.feedbackOnTap) DeskHaptics.selection();
    if (!_reduced) {
      _scale.animateTo(
        widget.scaleDown,
        duration: const Duration(milliseconds: 105),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _release() {
    _pressed = false;
    // InkWell may cancel a press as its subtree deactivates. Use the
    // cached motion setting; don't look up inherited widgets here.
    if (_scale.value == 1) {
      _scale.stop();
    } else if (_reduced) {
      _scale.value = 1;
    } else {
      _scale.animateWith(SpringSimulation(_spring, _scale.value, 1, 0));
    }
  }

  void _activate() {
    if (!_pressed && widget.feedbackOnTap) DeskHaptics.selection();
    _release();
    widget.onTap();
  }

  void _openSettings() {
    _release();
    DeskHaptics.heavy();
    widget.onLongPress?.call();
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final longPress = widget.onLongPress == null ? null : _openSettings;
    final radius = BorderRadius.circular(999);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      hint: widget.hint,
      onTap: _activate,
      onLongPress: longPress,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.hint == null
            ? widget.label
            : '${widget.label} · ${widget.hint}',
        triggerMode: TooltipTriggerMode.manual,
        excludeFromSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            enableFeedback: false,
            excludeFromSemantics: true,
            splashFactory: NoSplash.splashFactory,
            onFocusChange: (focused) {
              if (mounted && focused != _focused)
                setState(() => _focused = focused);
            },
            onTapDown: _down,
            onTapCancel: _release,
            onTap: _activate,
            onLongPress: longPress,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: _focused
                    ? Border.all(color: PersonalAppColors.inkObsidian, width: 2)
                    : null,
              ),
              child: ScaleTransition(
                scale: _reduced ? const AlwaysStoppedAnimation(1.0) : _scale,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
