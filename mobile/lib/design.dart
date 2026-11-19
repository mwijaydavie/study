import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'study_data.dart';
import 'ui/desk_motion.dart';

abstract final class DeskColors {
  static const ink = Color(0xff222336);
  static const muted = Color(0xff646574);
  static const paper = Color(0xfff8f8f4);
  // Match Android's studydesk_launch_surface for a continuous first frame.
  static const launchSurface = Color(0xfffbf4e1);
  static const line = Color(0xffeae9e3);
  static const gold = Color(0xffffe7a6);
  static const goldEdge = Color(0xffecc66b);
  static const midnight = Color(0xff242438);
  static const white = Color(0xffffffff);
}

final deskSystemBars = SystemUiOverlayStyle.dark.copyWith(
  statusBarColor: Colors.transparent,
);

const violet = (surface: Color(0xffeee7ff), ink: Color(0xff594199));
const green = (surface: Color(0xffe3f2ea), ink: Color(0xff2f664b));
const blue = (surface: Color(0xffe4effe), ink: Color(0xff2f528a));
const peach = (surface: Color(0xffffecda), ink: Color(0xff8d4d23));
const gold = (surface: Color(0xffffefd0), ink: Color(0xff745015));

TextStyle deskType(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color color = DeskColors.ink,
  double? height,
  double? spacing,
}) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation.weight(weight.value.toDouble())],
  color: color,
  height: height,
  letterSpacing: spacing,
);

ThemeData deskTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: DeskColors.goldEdge,
        brightness: Brightness.light,
      ).copyWith(
        surface: DeskColors.white,
        primary: DeskColors.midnight,
        onSurface: DeskColors.ink,
        outline: DeskColors.muted,
        outlineVariant: DeskColors.line,
        secondaryContainer: gold.surface,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'PlusJakartaSans',
    scaffoldBackgroundColor: DeskColors.paper,
    dividerColor: DeskColors.line,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: DeskColors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: DeskColors.gold,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected)
              ? gold.ink
              : DeskColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => deskType(
          10,
          weight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: DeskColors.midnight,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class DeskPage extends StatelessWidget {
  const DeskPage({super.key, required this.clock, required this.children});
  final CampusClock clock;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      MediaQuery.sizeOf(context).width < 345 ? 12 : 16,
      16,
      MediaQuery.sizeOf(context).width < 345 ? 12 : 16,
      8,
    ),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...children,
            const SizedBox(height: 22),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 5,
                spacing: 14,
                children: [
                  Text(
                    'StudyDesk · Mwijay’s workspace',
                    style: deskType(10, color: DeskColors.muted),
                  ),
                  Text(
                    '${clock.dateLabel} · EAT (UTC+3)',
                    style: deskType(10, color: DeskColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DeskHero extends StatelessWidget {
  const DeskHero({
    super.key,
    required this.title,
    required this.caption,
    required this.subtitle,
    required this.meta,
    required this.icon,
    this.art = false,
    this.background = DeskColors.gold,
    this.accent = const Color(0xff865b10),
  });
  final String title;
  final String caption;
  final String subtitle;
  final String meta;
  final IconData icon;
  final bool art;
  final Color background;
  final Color accent;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final roomy = box.maxWidth > 600;
      final compact = box.maxWidth < 320;
      final showArt =
          box.maxWidth >= 275 &&
          MediaQuery.textScalerOf(context).scale(13) < 20;
      final artWidth = roomy
          ? 220.0
          : (box.maxWidth * .33).clamp(88.0, 162.0).toDouble();
      final titleSize = roomy
          ? 49.0
          : (box.maxWidth * .093).clamp(26.5, 38.0).toDouble();
      return DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          gradient: art
              ? const LinearGradient(
                  colors: [Color(0xffffedb8), Color(0xffffdf93)],
                )
              : null,
          border: Border.all(color: accent.withValues(alpha: .19)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              if (showArt)
                Positioned(
                  right: roomy ? 42 : 3,
                  top: 0,
                  bottom: 0,
                  width: artWidth,
                  child: ExcludeSemantics(
                    child: Center(
                      child: art
                          ? Image.asset(
                              'assets/art/planner.webp',
                              fit: BoxFit.contain,
                            )
                          : Container(
                              width: artWidth * .74,
                              height: artWidth * .74,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.withValues(alpha: .08),
                                border: Border.all(
                                  color: accent.withValues(alpha: .19),
                                ),
                              ),
                              child: Icon(
                                icon,
                                size: artWidth * .48,
                                color: accent.withValues(alpha: .78),
                              ),
                            ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  roomy
                      ? 32
                      : compact
                      ? 14
                      : 18,
                  roomy
                      ? 25
                      : compact
                      ? 13
                      : 17,
                  showArt ? artWidth + (roomy ? 45 : 3) : 16,
                  roomy
                      ? 26
                      : compact
                      ? 13
                      : 17,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Pill(
                      caption,
                      icon: icon,
                      background: Colors.white.withValues(alpha: .58),
                      color: DeskColors.ink,
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      header: true,
                      child: Text.rich(
                        TextSpan(
                          text: title,
                          style: deskType(
                            titleSize,
                            weight: FontWeight.w800,
                            height: 1.11,
                            spacing: -1.7,
                          ),
                          children: [
                            TextSpan(
                              text: '.',
                              style: TextStyle(color: accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: deskType(12, color: DeskColors.ink, height: 1.40),
                    ),
                    const SizedBox(height: 12),
                    MetaLabel(
                      Icons.calendar_today_outlined,
                      meta,
                      size: 11,
                      color: accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class DeskCard extends StatelessWidget {
  const DeskCard({
    super.key,
    required this.child,
    this.onTap,
    this.color = DeskColors.white,
    this.border = DeskColors.line,
    this.padding = const EdgeInsets.all(14),
  });
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: deskType(22, weight: FontWeight.w800, spacing: -.7),
        ),
      ),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: deskType(11.5, color: DeskColors.muted, height: 1.35),
      ),
    ],
  );
}

class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.icon,
    this.background = DeskColors.gold,
    this.color = DeskColors.ink,
  });
  final String text;
  final IconData? icon;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(25),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              style: deskType(
                9.5,
                color: color,
                weight: FontWeight.w800,
                spacing: .25,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class MetaLabel extends StatelessWidget {
  const MetaLabel(
    this.icon,
    this.text, {
    super.key,
    this.color = DeskColors.muted,
    this.size = 11,
  });
  final IconData icon;
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 5),
      Flexible(
        child: Text(text, style: deskType(size, color: color)),
      ),
    ],
  );
}

class DeskGlyph extends StatelessWidget {
  const DeskGlyph(this.icon, {super.key, this.tones = violet, this.size = 36});
  final IconData icon;
  final ({Color ink, Color surface}) tones;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: tones.surface,
      borderRadius: BorderRadius.circular(11),
    ),
    alignment: Alignment.center,
    child: Icon(icon, size: size * .53, color: tones.ink),
  );
}

({Color ink, Color surface}) courseTone(String? tone) => switch (tone) {
  'blue' => blue,
  'green' => green,
  'violet' => violet,
  _ => peach,
};

IconData courseIcon(String? code) => switch (code) {
  'CS243' => Icons.laptop_mac_outlined,
  'IS274' => Icons.code_rounded,
  'IS264' => Icons.storage_rounded,
  'ST119' => Icons.calculate_outlined,
  'IS237' || 'networking' => Icons.hub_outlined,
  'FN200' => Icons.account_balance_outlined,
  'tools' => Icons.folder_outlined,
  _ => Icons.church_outlined,
};

Future<void> deskSheet(
  BuildContext context, {
  required String label,
  required String title,
  required List<Widget> children,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  sheetAnimationStyle: DeskMotion.sheetOf(context),
  backgroundColor: DeskColors.white,
  builder: (sheet) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheet).height * .80,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: deskType(
                      10,
                      color: violet.ink,
                      spacing: 1.1,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(sheet).pop(),
                ),
              ],
            ),
            Text(
              title,
              style: deskType(24, weight: FontWeight.w800, spacing: -.7),
            ),
            const SizedBox(height: 13),
            ...children,
          ],
        ),
      ),
    ),
  ),
);
