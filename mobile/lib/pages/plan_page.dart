import 'package:flutter/material.dart';

import '../design.dart';
import '../study_data.dart';
import '../study_files.dart';
import '../workspace.dart';

class PlanPage extends StatelessWidget {
  const PlanPage({
    super.key,
    required this.data,
    required this.clock,
    required this.workspace,
    required this.openFolder,
  });
  final StudyData data;
  final CampusClock clock;
  final Workspace workspace;
  final ValueChanged<String> openFolder;

  @override
  Widget build(BuildContext context) {
    final done = workspace.doneFor(clock.weekKey);
    final completed = data.blocks
        .where((block) => done.contains(block.id))
        .length;
    final total = data.blocks.length;
    final fraction = total > 0 ? completed / total : 0.0;
    final minutes = data.blocks.fold(0, (sum, block) => sum + block.minutes);
    return DeskPage(
      clock: clock,
      children: [
        DeskHero(
          title: 'My study plan',
          caption: 'PERSONAL STUDY TIME',
          subtitle: 'One small task at a time. Jifunze, jaribu, rudia.',
          meta: '${clock.weekLabel} · EAT',
          icon: Icons.track_changes_outlined,
          background: violet.surface,
          accent: violet.ink,
        ),
        const SizedBox(height: 15),
        DeskCard(
          color: violet.surface,
          border: const Color(0xffe4d8fa),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetaLabel(
                Icons.track_changes_outlined,
                'THIS WEEK',
                color: violet.ink,
              ),
              const SizedBox(height: 5),
              Text(
                '$completed / $total done',
                key: const Key('weekly-progress'),
                style: deskType(25, weight: FontWeight.w800, spacing: -.6),
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 7,
                  backgroundColor: const Color(0xffded2f5),
                  color: violet.ink,
                  semanticsLabel: 'Weekly study progress',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(fraction * 100).round()}% complete · ${workspace.canSave ? 'Saved on this device' : 'Not saved across launches'}',
                style: deskType(11, color: violet.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionTitle(
          'Your study blocks',
          'Suggested, not extra classes · ${formatDuration(minutes)} total',
        ),
        const SizedBox(height: 9),
        for (final block in data.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _StudyCard(
              block: block,
              course: data.courses[block.code],
              use24Hour: workspace.use24Hour,
              completed: done.contains(block.id),
              toggle: () => workspace.toggleTask(clock.weekKey, block.id),
              openFolder: () => openFolder(block.code),
            ),
          ),
        const SizedBox(height: 5),
        DeskCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A simple study routine',
                style: deskType(14, weight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Recall the main idea. Practise with one example. Review what you’ll revisit next time.',
                style: deskType(12, color: DeskColors.muted, height: 1.55),
              ),
              const Divider(height: 20),
              const MetaLabel(
                Icons.schedule_rounded,
                'The checklist starts fresh every Monday, EAT.',
              ),
              Builder(
                builder: (button) => TextButton.icon(
                  onPressed: () => plannerFile.share(button),
                  icon: const Icon(Icons.ios_share_outlined, size: 17),
                  label: const Text('Share editable planner'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({
    required this.block,
    required this.course,
    required this.use24Hour,
    required this.completed,
    required this.toggle,
    required this.openFolder,
  });
  final StudyBlock block;
  final Course? course;
  final bool use24Hour, completed;
  final VoidCallback toggle, openFolder;

  @override
  Widget build(BuildContext context) {
    final tone = courseTone(course?.tone);
    return DeskCard(
      key: ValueKey('study-${block.id}'),
      color: completed ? const Color(0xfff9fdf9) : DeskColors.white,
      border: completed ? const Color(0xffd7e8dc) : DeskColors.line,
      padding: const EdgeInsets.fromLTRB(11, 10, 8, 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeskGlyph(courseIcon(block.code), tones: tone, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 3,
                  children: [
                    Text(
                      '${dayName(block.day)} · ${formatRange(block.start, block.end, use24Hour: use24Hour)}',
                      style: deskType(10, color: DeskColors.muted),
                    ),
                    Text(
                      block.code,
                      style: deskType(
                        10,
                        color: tone.ink,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  block.title,
                  style: deskType(14, weight: FontWeight.w800, height: 1.28),
                ),
                const SizedBox(height: 5),
                Text(
                  block.work,
                  style: deskType(11.5, color: DeskColors.muted, height: 1.5),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: violet.surface, width: 2),
                    ),
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: deskType(
                        11.5,
                        color: DeskColors.muted,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: 'Make: ',
                          style: deskType(11.5, weight: FontWeight.w800),
                        ),
                        TextSpan(text: block.output),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: openFolder,
                  icon: const Icon(Icons.north_east, size: 14),
                  label: const Text('Course folder'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    foregroundColor: violet.ink,
                    textStyle: deskType(11, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: completed ? 'Mark not done' : 'Mark done',
            child: Semantics(
              label: 'Completed: ${block.title}',
              child: Checkbox(
                key: ValueKey('done-${block.id}'),
                value: completed,
                onChanged: (_) => toggle(),
                activeColor: green.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
