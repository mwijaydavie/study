import 'package:flutter/material.dart';

import '../design.dart';
import '../reminders/reminders.dart';
import '../study_data.dart';
import '../study_files.dart';
import '../workspace.dart';
import 'reminders_page.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({
    super.key,
    required this.data,
    required this.clock,
    required this.workspace,
    required this.openFolder,
    this.reminders,
  });
  final StudyData data;
  final CampusClock clock;
  final Workspace workspace;
  final ValueChanged<String> openFolder;
  final ReminderController? reminders;

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  int? _selectedDay;
  StudyData get data => widget.data;
  CampusClock get clock => widget.clock;
  Workspace get workspace => widget.workspace;

  void _openDetails(Session session) => showTimetableSession(
    context,
    data: data,
    session: session,
    workspace: workspace,
    openFolder: widget.openFolder,
    reminders: widget.reminders,
  );

  @override
  Widget build(BuildContext context) {
    final day = _selectedDay ?? clock.weekday;
    final dayView = workspace.view == ScheduleView.day;
    final next = data.upcoming(clock);
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            const SectionTitle(
              'Class schedule',
              'Weekly timetable · East Africa Time',
            ),
            SegmentedButton<ScheduleView>(
              segments: const [
                ButtonSegment(value: ScheduleView.day, label: Text('Day')),
                ButtonSegment(value: ScheduleView.week, label: Text('Week')),
              ],
              selected: {workspace.view},
              showSelectedIcon: false,
              style: ButtonStyle(
                textStyle: WidgetStatePropertyAll(
                  deskType(11, weight: FontWeight.w800),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12),
                ),
                minimumSize: const WidgetStatePropertyAll(Size(40, 36)),
                visualDensity: VisualDensity.compact,
                side: const WidgetStatePropertyAll(
                  BorderSide(color: DeskColors.line),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                foregroundColor: const WidgetStatePropertyAll(DeskColors.ink),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? DeskColors.gold
                      : DeskColors.white,
                ),
              ),
              onSelectionChanged: (selection) =>
                  workspace.setView(selection.first),
            ),
          ],
        ),
        if (dayView) ...[
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) {
              final fontScale = MediaQuery.textScalerOf(context).scale(11) / 11;
              final cell = (box.maxWidth - 20) / 5;
              final width = fontScale > 1.30 && cell < 76 ? 76.0 : cell;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 1; index <= 5; index++) ...[
                      if (index > 1) const SizedBox(width: 5),
                      SizedBox(
                        width: width,
                        child: _Weekday(
                          index: index,
                          selected: day == index,
                          today: index == clock.weekday,
                          count: data.onDay(index).length,
                          onSelected: () =>
                              setState(() => _selectedDay = index),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          if (day != clock.weekday)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _selectedDay = null),
                child: const Text('Back to today'),
              ),
            ),
        ],
        const SizedBox(height: 12),
        for (final index in dayView ? [day] : [1, 2, 3, 4, 5]) ...[
          _DayList(
            day: index,
            today: index == clock.weekday,
            data: data,
            use24Hour: workspace.use24Hour,
            onOpen: _openDetails,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );

    final upNext = next == null
        ? null
        : _NextCard(
            upcoming: next,
            data: data,
            use24Hour: workspace.use24Hour,
            onOpen: () => _openDetails(next.session),
          );
    final summary = _Overview(data: data);
    return DeskPage(
      clock: clock,
      children: [
        DeskHero(
          title: 'My timetable',
          caption: 'UAUT · ${data.cohort.toUpperCase()}',
          subtitle: 'Habari, Mwijay! Here’s your class week at a glance.',
          meta: data.termLabel,
          icon: Icons.school_outlined,
          art: true,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth >= 720) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: controls),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (upNext != null) ...[
                          upNext,
                          const SizedBox(height: 12),
                        ],
                        summary,
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (upNext != null) ...[upNext, const SizedBox(height: 14)],
                controls,
                summary,
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Weekday extends StatelessWidget {
  const _Weekday({
    required this.index,
    required this.selected,
    required this.today,
    required this.count,
    required this.onSelected,
  });
  final int index, count;
  final bool selected, today;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${dayName(index)}, $count sessions${today ? ', today' : ''}',
    child: DeskCard(
      color: selected ? DeskColors.gold : DeskColors.white,
      border: selected ? DeskColors.goldEdge : DeskColors.line,
      onTap: onSelected,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 3,
              children: [
                Text(
                  dayName(index).substring(0, 3),
                  style: deskType(12, weight: FontWeight.w800),
                ),
                if (today)
                  const Icon(Icons.circle, size: 5, color: Color(0xff976303)),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '$count sessions',
              textAlign: TextAlign.center,
              style: deskType(9, color: DeskColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DayList extends StatelessWidget {
  const _DayList({
    required this.day,
    required this.today,
    required this.data,
    required this.use24Hour,
    required this.onOpen,
  });
  final int day;
  final bool today, use24Hour;
  final StudyData data;
  final ValueChanged<Session> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = data.onDay(day);
    final duration = items.fold(0, (sum, item) => sum + item.minutes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 5,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 7,
              children: [
                Text(
                  dayName(day),
                  style: deskType(16, weight: FontWeight.w800),
                ),
                if (today) const Pill('Today'),
              ],
            ),
            Text(
              '${items.length} sessions${items.isEmpty ? '' : ' · ${formatDuration(duration)}'}',
              style: deskType(10.5, color: DeskColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          DeskCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DeskGlyph(Icons.wb_sunny_outlined, tones: peach),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No scheduled classes',
                        style: deskType(14, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Take a break or do a short review.',
                        style: deskType(12, color: DeskColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SessionCard(
                item: item,
                data: data,
                use24Hour: use24Hour,
                onTap: () => onOpen(item),
              ),
            ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.item,
    required this.data,
    required this.use24Hour,
    required this.onTap,
  });
  final Session item;
  final StudyData data;
  final bool use24Hour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final course = data.courses[item.code];
    final tone = courseTone(course?.tone);
    return DeskCard(
      onTap: onTap,
      padding: const EdgeInsets.all(11),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: use24Hour ? 49 : 61,
                minWidth: use24Hour ? 44 : 57,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatTime(item.start, use24Hour: use24Hour),
                    style: deskType(12, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatTime(item.end, use24Hour: use24Hour),
                    style: deskType(10.5, color: DeskColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (box.maxWidth > 235 &&
                MediaQuery.textScalerOf(context).scale(14) <= 20) ...[
              DeskGlyph(courseIcon(item.code), tones: tone, size: 34),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      if (item.code != null)
                        Text(
                          item.code!,
                          style: deskType(
                            9.5,
                            color: tone.ink,
                            weight: FontWeight.w800,
                          ),
                        ),
                      Pill(
                        item.kindLabel,
                        background: tone.surface,
                        color: tone.ink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.titleFor(item),
                    style: deskType(13, weight: FontWeight.w800, height: 1.25),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      MetaLabel(Icons.place_outlined, item.venue, size: 10),
                      if (course != null)
                        MetaLabel(
                          Icons.person_outline_rounded,
                          course.lecturer,
                          size: 10,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right, color: DeskColors.muted, size: 16),
          ],
        ),
      ),
    );
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({
    required this.upcoming,
    required this.data,
    required this.use24Hour,
    required this.onOpen,
  });
  final UpcomingSession upcoming;
  final StudyData data;
  final bool use24Hour;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final item = upcoming.session;
    const light = Color(0xffe9e0fa);
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: DeskColors.midnight)),
          for (final size in [150.0, 183.0])
            Positioned(
              top: -85,
              right: -50,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x39b4a1f0)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 5,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 13,
                          height: 13,
                          decoration: const BoxDecoration(
                            color: Color(0x30ffe7a6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.circle,
                            size: 7,
                            color: Color(0xfff6d889),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            upcoming.inProgress ? 'SCHEDULED NOW' : 'UP NEXT',
                            style: deskType(
                              10,
                              color: light,
                              weight: FontWeight.w800,
                              spacing: .65,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${upcoming.dayLabel} · ${formatRange(item.start, item.end, use24Hour: use24Hour)}',
                      style: deskType(
                        10.5,
                        weight: FontWeight.w800,
                        color: const Color(0xfff6d889),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  data.titleFor(item),
                  style: deskType(
                    17,
                    weight: FontWeight.w800,
                    color: DeskColors.white,
                    height: 1.26,
                  ),
                ),
                const SizedBox(height: 6),
                const Divider(color: Color(0x35ffffff), height: 1),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    MetaLabel(Icons.place_outlined, item.venue, color: light),
                    TextButton.icon(
                      onPressed: onOpen,
                      style: TextButton.styleFrom(
                        foregroundColor: light,
                        textStyle: deskType(11, weight: FontWeight.w800),
                      ),
                      icon: const Icon(Icons.north_east, size: 14),
                      label: const Text('Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data});
  final StudyData data;

  @override
  Widget build(BuildContext context) {
    final classTime = data.sessions
        .where((item) => item.kind != 'chapel')
        .fold(0, (sum, item) => sum + item.minutes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DeskCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Semester at a glance',
                style: deskType(14, weight: FontWeight.w800),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  MetaLabel(
                    Icons.menu_book_outlined,
                    '${data.courses.length} courses',
                    color: violet.ink,
                  ),
                  MetaLabel(
                    Icons.event_note_outlined,
                    '${data.sessions.length} weekly sessions',
                    color: green.ink,
                  ),
                ],
              ),
              const Divider(height: 22),
              MetaLabel(
                Icons.schedule_rounded,
                '${formatDuration(classTime)} of class time + 1h Wednesday Chapel',
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        DeskCard(
          color: const Color(0xfffcf7e9),
          border: const Color(0xffede4cc),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetaLabel(
                Icons.info_outline,
                'Revised draft',
                color: gold.ink,
                size: 13,
              ),
              const SizedBox(height: 5),
              Text(
                'From the UAUT timetable, p. ${data.sourcePage}. Confirm room or time changes with the university.',
                style: deskType(11, color: gold.ink, height: 1.45),
              ),
              Builder(
                builder: (buttonContext) => TextButton.icon(
                  onPressed: () => timetableFile.share(buttonContext),
                  icon: const Icon(Icons.ios_share_outlined, size: 16),
                  label: const Text('Share timetable PDF'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> showTimetableSession(
  BuildContext context, {
  required StudyData data,
  required Session session,
  required Workspace workspace,
  required ValueChanged<String> openFolder,
  ReminderController? reminders,
  DateTime? confirmedDay,
}) {
  final course = data.courses[session.code];
  final when =
      '${confirmedDay == null ? dayName(session.day) : campusDayLabel(confirmedDay)} · ${formatRange(session.start, session.end, use24Hour: workspace.use24Hour)} EAT';
  return deskSheet(
    context,
    label: [session.code, session.kindLabel].nonNulls.join(' · '),
    title: data.titleFor(session),
    children: [
      _DetailLine(Icons.calendar_today_outlined, 'When', when),
      _DetailLine(
        Icons.schedule_rounded,
        'Duration',
        formatDuration(session.minutes),
      ),
      _DetailLine(Icons.place_outlined, 'Venue', session.venue),
      if (reminders != null && session.code != null) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('remind-from-class-details'),
            onPressed: () {
              Navigator.of(context).pop();
              editClassReminder(
                context,
                reminders: reminders,
                session: session,
                use24Hour: workspace.use24Hour,
              );
            },
            icon: const Icon(Icons.notifications_outlined, size: 17),
            label: const Text('Set class reminder'),
          ),
        ),
      ],
      if (course != null) ...[
        _DetailLine(Icons.person_outline_rounded, 'Lecturer', course.lecturer),
        const SizedBox(height: 10),
        DeskCard(
          color: violet.surface,
          border: violet.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Suggested follow-up',
                style: deskType(12, color: violet.ink, weight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                course.focus,
                style: deskType(12, color: violet.ink, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              openFolder(course.code);
            },
            icon: const Icon(Icons.folder_open_outlined, size: 17),
            label: const Text('Open course folder'),
          ),
        ),
      ],
    ],
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: MetaLabel(icon, label, size: 12)),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: deskType(12, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
      const Divider(height: 15),
    ],
  );
}
