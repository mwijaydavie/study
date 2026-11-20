import 'dart:ui' as ui;

import 'package:flutter/material.dart';

abstract final class PersonalAppColors {
  static const canvasWhite = Color(0xfffffdf8);
  static const pureWhite = Color(0xffffffff);
  static const solarGlowSoft = Color(0xfffff1b8);
  static const solarYellowMain = Color(0xffffd447);
  static const solarAmberDeep = Color(0xfff4b400);
  static const activePillWash = Color(0xffffe57f);
  static const inkObsidian = Color(0xff1a1814);
  static const inkMuted = Color(0xff7a7367);
  static const goldenShadow = Color(0xffc89b1e);
}

/// The warm light behind the glass is static and repaints only on resize.
class AmbientSolarBackdrop extends StatelessWidget {
  const AmbientSolarBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const RepaintBoundary(
        child: ColoredBox(
          color: PersonalAppColors.canvasWhite,
          child: CustomPaint(painter: _SolarMesh()),
        ),
      ),
      child,
    ],
  );
}

class _SolarMesh extends CustomPainter {
  const _SolarMesh();

  @override
  void paint(Canvas canvas, Size size) {
    void bloom(Offset center, double radius, Color color, double opacity) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    bloom(
      Offset(size.width * .84, size.height * .14),
      size.width * .65,
      PersonalAppColors.solarGlowSoft,
      .78,
    );
    bloom(
      Offset(size.width * .52, size.height * .89),
      size.width * .85,
      PersonalAppColors.solarYellowMain,
      .34,
    );
  }

  @override
  bool shouldRepaint(covariant _SolarMesh oldDelegate) => false;
}

/// A bounded blur with a solid high-contrast fallback for glass surfaces.
class SolarGlass extends StatelessWidget {
  const SolarGlass({
    super.key,
    required this.radius,
    required this.child,
    this.blur = 22,
    this.padding = EdgeInsets.zero,
  });
  final double radius, blur;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final solid = MediaQuery.highContrastOf(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PersonalAppColors.pureWhite.withValues(alpha: solid ? 1 : .86),
            const Color(0xfffffdf5).withValues(alpha: solid ? 1 : .74),
          ],
        ),
        border: Border.all(
          color: PersonalAppColors.pureWhite.withValues(alpha: .92),
          width: 1.2,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: PersonalAppColors.goldenShadow.withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          const BoxShadow(
            color: Color(0x0a1a1814),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: solid
            ? surface
            : BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: surface,
              ),
      ),
    );
  }
}
