import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/personal_yellow_theme.dart';
import '../coach/assistant_preferences.dart';
import '../design.dart';
import '../study_data.dart';
import '../workspace.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.data,
    required this.clock,
    required this.workspace,
    required this.openAssistant,
    required this.openTimetable,
    required this.openPlan,
    required this.openFinance,
  });

  final StudyData data;
  final CampusClock clock;
  final Workspace workspace;
  final ValueChanged<String> openAssistant;
  final VoidCallback openTimetable, openPlan, openFinance;

  @override
  Widget build(BuildContext context) => DeskPage(
    clock: clock,
    children: [
      _DayHero(clock: clock),
      const SizedBox(height: 12),
      _QuickCapture(open: openAssistant),
      const SizedBox(height: 18),
      const SectionTitle(
        'Your day at a glance',
        'Classes, your own study blocks, and something to revise.',
      ),
      const SizedBox(height: 9),
      LayoutBuilder(
        builder: (context, box) {
          final sideBySide =
              box.maxWidth >= 346 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          final plan = _PlanPreview(
            data: data,
            clock: clock,
            workspace: workspace,
            openTimetable: openTimetable,
            openPlan: openPlan,
          );
          final finance = _FinancePreview(
            title:
                data.guides['finance-risk-return']?.title ?? 'FN200 revision',
            open: openFinance,
          );
          if (sideBySide) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: plan),
                  const SizedBox(width: 10),
                  Expanded(child: finance),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [plan, const SizedBox(height: 10), finance],
          );
        },
      ),
      const SizedBox(height: 18),
      _PinnedNotes(preferences: workspace.assistant),
    ],
  );
}

class _DayHero extends StatelessWidget {
  const _DayHero({required this.clock});
  final CampusClock clock;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 630;
      final showSeal =
          box.maxWidth >= 316 &&
          MediaQuery.textScalerOf(context).scale(15) < 19;
      final hour = clock.campusTime.hour;
      final greeting = hour < 12
          ? 'Habari za asubuhi'
          : hour < 17
          ? 'Habari za mchana'
          : 'Habari za jioni';
      final inset = wide ? 26.0 : 16.0;
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xfffffcf1), Color(0xffffe491), Color(0xffffd658)],
            stops: [0, .62, 1],
          ),
          border: Border.all(color: const Color(0xfff3dd9d)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x17c89b1e),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              if (showSeal)
                PositionedDirectional(
                  end: wide ? 32 : 11,
                  top: 0,
                  bottom: 0,
                  width: wide ? 166 : 104,
                  child: const IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(painter: _SunSeal()),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  inset,
                  16,
                  showSeal ? (wide ? 204 : 115) : inset,
                  18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Pill(
                      '${clock.dateLabel.toUpperCase()} · EAT',
                      icon: Icons.wb_sunny_outlined,
                      background: const Color(0xbdffffff),
                      color: const Color(0xff62490d),
                    ),
                    const SizedBox(height: 11),
                    Text(
                      greeting,
                      style: deskType(
                        12,
                        weight: FontWeight.w700,
                        color: const Color(0xff6a5019),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Semantics(
                      header: true,
                      child: Text(
                        'Mwijay.',
                        style: deskType(
                          wide ? 54 : 41,
                          height: 1.13,
                          weight: FontWeight.w800,
                          spacing: -2.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your study day in Dar es Salaam.',
                      style: deskType(12, height: 1.4),
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

class _SunSeal extends CustomPainter {
  const _SunSeal();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .51);
    final radius = size.shortestSide * .38;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.27, -.33),
          radius: 1.05,
          colors: [Color(0xfffffcdd), Color(0xffffde75), Color(0xffffbf31)],
        ).createShader(rect),
    );
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;
    canvas.drawCircle(
      center,
      radius * 1.20,
      rim..color = const Color(0x55916312),
    );
    canvas.drawCircle(
      center,
      radius * 1.38,
      rim..color = const Color(0x33916312),
    );
    canvas.drawCircle(center, radius - 1, rim..color = const Color(0xf5ffffeb));
    canvas.drawCircle(
      center + Offset(radius * .88, -radius * .80),
      3.8,
      Paint()..color = const Color(0xff806016),
    );
    canvas.drawCircle(
      center + Offset(-radius * 1.17, radius * .73),
      2.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _SunSeal oldDelegate) => false;
}

class _QuickCapture extends StatefulWidget {
  const _QuickCapture({required this.open});
  final ValueChanged<String> open;

  @override
  State<_QuickCapture> createState() => _QuickCaptureState();
}

class _QuickCaptureState extends State<_QuickCapture> {
  final _text = TextEditingController();

  void _send() {
    final value = _text.text.trim();
    FocusScope.of(context).unfocus();
    _text.clear();
    widget.open(value);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SolarGlass(
    radius: 18,
    blur: 14,
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MetaLabel(
              Icons.auto_awesome_rounded,
              'QUICK CAPTURE',
              color: gold.ink,
            ),
            const Pill(
              'ON DEVICE',
              icon: Icons.lock_outline_rounded,
              background: Color(0xfffff3d2),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Ask about today, or capture a note.',
          style: deskType(15, weight: FontWeight.w800),
        ),
        const SizedBox(height: 9),
        TextField(
          key: const Key('home-capture'),
          controller: _text,
          textInputAction: TextInputAction.go,
          inputFormatters: [
            LengthLimitingTextInputFormatter(AssistantPreferences.noteLimit),
          ],
          onSubmitted: (_) => _send(),
          style: deskType(13),
          decoration: InputDecoration(
            hintText: 'Try “Leo” or “FN200”…',
            labelText: 'Ask or write a note',
            floatingLabelBehavior: FloatingLabelBehavior.never,
            filled: true,
            fillColor: DeskColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: DeskColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: DeskColors.line),
            ),
            suffixIcon: IconButton(
              key: const Key('home-send'),
              tooltip: 'Open Assistant',
              onPressed: _send,
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PlanPreview extends StatelessWidget {
  const _PlanPreview({
    required this.data,
    required this.clock,
    required this.workspace,
    required this.openTimetable,
    required this.openPlan,
  });
  final StudyData data;
  final CampusClock clock;
  final Workspace workspace;
  final VoidCallback openTimetable, openPlan;

  @override
  Widget build(BuildContext context) {
    final today = data.onDay(clock.weekday);
    final planned = data.blocks
        .where((block) => block.day == clock.weekday)
        .length;
    final next = data.upcoming(clock);
    return DeskCard(
      color: const Color(0xfffffcf3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DeskGlyph(Icons.event_note_outlined, tones: gold),
          const SizedBox(height: 8),
          Text(
            'Today’s plan',
            style: deskType(17, weight: FontWeight.w800, spacing: -.4),
          ),
          const SizedBox(height: 4),
          Text(
            '${today.length} campus ${today.length == 1 ? 'activity' : 'activities'} · $planned suggested ${planned == 1 ? 'block' : 'blocks'}',
            style: deskType(12, height: 1.45, color: DeskColors.muted),
          ),
          if (next != null) ...[
            const SizedBox(height: 10),
            Text(
              next.inProgress ? 'IN PROGRESS' : 'UP NEXT',
              style: deskType(
                9,
                weight: FontWeight.w800,
                spacing: .9,
                color: gold.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${next.dayLabel} · ${formatTime(next.session.start, use24Hour: workspace.use24Hour)} EAT',
              style: deskType(11.5, weight: FontWeight.w800),
            ),
            Text(
              '${next.session.code ?? data.titleFor(next.session)} · ${next.session.venue}',
              style: deskType(12, height: 1.4, color: DeskColors.muted),
            ),
          ],
          const SizedBox(height: 5),
          TextButton(
            key: const Key('home-timetable'),
            onPressed: openTimetable,
            child: const Text('Timetable'),
          ),
          TextButton(
            key: const Key('home-checklist'),
            onPressed: openPlan,
            child: const Text('Study checklist'),
          ),
        ],
      ),
    );
  }
}

class _FinancePreview extends StatelessWidget {
  const _FinancePreview({required this.title, required this.open});
  final String title;
  final VoidCallback open;

  @override
  Widget build(BuildContext context) => DeskCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DeskGlyph(Icons.folder_copy_outlined, tones: gold),
        const SizedBox(height: 8),
        Text(
          'Materials',
          style: deskType(17, weight: FontWeight.w800, spacing: -.4),
        ),
        const SizedBox(height: 4),
        const Pill(
          'FN200',
          icon: Icons.bookmark_outline_rounded,
          background: Color(0xfffff3d2),
        ),
        const SizedBox(height: 7),
        Text(title, style: deskType(14, weight: FontWeight.w800, height: 1.3)),
        const SizedBox(height: 4),
        Text(
          'Read a guide, work through an example, then test yourself offline.',
          style: deskType(12, color: DeskColors.muted, height: 1.45),
        ),
        const SizedBox(height: 5),
        TextButton(
          key: const Key('home-fn200'),
          onPressed: open,
          child: const Text('Open FN200'),
        ),
      ],
    ),
  );
}

class _PinnedNotes extends StatelessWidget {
  const _PinnedNotes({required this.preferences});
  final AssistantPreferences preferences;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: preferences,
    builder: (context, _) {
      final pins = preferences.pins;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(
            'Pinned notes',
            'Only the notes you choose to save, on this device.',
          ),
          const SizedBox(height: 8),
          if (pins.isEmpty)
            DeskCard(
              child: MetaLabel(
                Icons.push_pin_outlined,
                preferences.memory
                    ? 'Capture a note above and choose Pin note.'
                    : 'Turn on note memory in AI Settings to pin a capture.',
              ),
            ),
          for (final note in pins)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: DeskCard(
                padding: const EdgeInsets.fromLTRB(12, 5, 5, 5),
                child: Row(
                  children: [
                    const Icon(Icons.push_pin_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(note, style: deskType(13, height: 1.4)),
                    ),
                    IconButton(
                      tooltip: 'Unpin note',
                      onPressed: () => preferences.unpin(note),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
