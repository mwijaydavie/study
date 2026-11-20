import 'package:flutter/material.dart';

import '../design.dart';
import '../documents/personal_documents.dart';
import '../study_data.dart';
import '../study_files.dart';
import '../ui/desk_motion.dart';
import 'personal_documents_page.dart';

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({
    super.key,
    required this.data,
    required this.clock,
    this.initialFolder = '',
    this.documents,
    this.openCoach,
  });
  final StudyData data;
  final CampusClock clock;
  final String initialFolder;
  final DocumentLibrary? documents;
  final VoidCallback? openCoach;

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  late String _filter = widget.initialFolder;
  final _search = TextEditingController();

  @override
  void didUpdateWidget(MaterialsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFolder != widget.initialFolder)
      _filter = widget.initialFolder;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Folder> _folders() {
    final data = widget.data;
    final group = <String, List<_Resource>>{
      'IS274': [
        if (data.guides['ooad'] case final guide?) _Resource.guide(guide),
        const _Resource.file(slidesFile),
      ],
      'IS264': [
        if (data.guides['sql'] case final guide?) _Resource.guide(guide),
      ],
      'FN200': [
        for (final key in financeGuideKeys)
          if (data.guides[key] case final guide?) _Resource.guide(guide),
      ],
    };
    return [
      for (final code in group.keys)
        if (data.courses[code] case final course?)
          _Folder(
            code,
            course.title,
            course.focus,
            courseTone(course.tone),
            group[code]!,
          ),
      _Folder(
        'networking',
        'Networking',
        'Supplementary notes. Confirm the course code with your lecturer.',
        blue,
        [
          for (final key in ['ip', 'subnet'])
            if (data.guides[key] case final guide?) _Resource.guide(guide),
        ],
      ),
      const _Folder(
        'tools',
        'Semester downloads',
        'A printable timetable and an editable planner.',
        peach,
        [_Resource.file(timetableFile), _Resource.file(plannerFile)],
      ),
      for (final course in data.courses.values)
        if (!group.containsKey(course.code))
          _Folder(
            course.code,
            course.title,
            course.focus,
            courseTone(course.tone),
            const [],
          ),
    ];
  }

  void _reset() => setState(() {
    _filter = '';
    _search.clear();
  });

  @override
  Widget build(BuildContext context) {
    final folders = _folders();
    final query = _search.text.trim().toLowerCase();
    final visible = folders
        .where(
          (folder) =>
              (_filter.isEmpty || _filter == folder.id) &&
              folder.matches(query),
        )
        .toList();
    return DeskPage(
      clock: widget.clock,
      children: [
        DeskHero(
          title: 'My materials',
          caption: 'STUDY LIBRARY',
          subtitle: 'Course folders, short guides, and editable files.',
          meta: widget.data.termLabel,
          icon: Icons.folder_open_outlined,
          background: green.surface,
          accent: green.ink,
        ),
        if (widget.documents case final library?) ...[
          const SizedBox(height: 12),
          DeskCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: const Key('personal-files-entry'),
              leading: const DeskGlyph(Icons.folder_outlined, tones: blue),
              title: Text(
                'My files',
                style: deskType(14, weight: FontWeight.w800),
              ),
              subtitle: Text(
                'Add your own PDF, Word and PowerPoint files',
                style: deskType(11.5, color: DeskColors.muted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => PersonalDocumentsPage(
                    library: library,
                    clock: widget.clock,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const SectionTitle(
          'Course folders',
          'Browse bundled guides and files, even offline.',
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          style: deskType(13),
          decoration: InputDecoration(
            labelText: 'Search materials',
            hintText: 'Find a topic or file…',
            floatingLabelBehavior: FloatingLabelBehavior.never,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: DeskColors.white,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: DeskColors.line),
              borderRadius: BorderRadius.circular(11),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () => setState(_search.clear),
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in [
                const MapEntry('', 'All folders'),
                ...folders.map(
                  (folder) => MapEntry(folder.id, folder.filterLabel),
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: entry.key == _filter,
                    onSelected: (selected) {
                      if (!selected || entry.key == _filter) return;
                      DeskHaptics.selection();
                      setState(() => _filter = entry.key);
                    },
                    labelStyle: deskType(
                      11,
                      color: entry.key == _filter ? green.ink : DeskColors.ink,
                    ),
                    selectedColor: green.surface,
                    backgroundColor: DeskColors.white,
                    side: const BorderSide(color: DeskColors.line),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        if (visible.isEmpty)
          DeskCard(
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, color: DeskColors.muted),
                const SizedBox(height: 5),
                Text(
                  'No matching folders',
                  style: deskType(14, weight: FontWeight.w800),
                ),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Clear search and filters'),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth >= 700
                  ? (box.maxWidth - 10) / 2
                  : box.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final folder in visible)
                    SizedBox(
                      width: width,
                      child: _FolderCard(
                        folder: folder,
                        onPractice: folder.id == 'FN200'
                            ? widget.openCoach
                            : null,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _Folder {
  const _Folder(this.id, this.title, this.description, this.tone, this.items);
  final String id, title, description;
  final ({Color ink, Color surface}) tone;
  final List<_Resource> items;

  String get filterLabel => switch (id) {
    'networking' => 'Networking',
    'tools' => 'Downloads',
    _ => id,
  };
  String get label => switch (id) {
    'networking' => 'COURSE UNCONFIRMED',
    'tools' => 'PRINT & EDIT',
    _ => id,
  };

  bool matches(String query) => [
    id,
    title,
    description,
    ...items.expand((item) => [item.title, item.description]),
  ].join(' ').toLowerCase().contains(query);
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.folder, this.onPractice});
  final _Folder folder;
  final VoidCallback? onPractice;

  @override
  Widget build(BuildContext context) => DeskCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            DeskGlyph(courseIcon(folder.id), tones: folder.tone),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.label,
                    style: deskType(
                      9,
                      color: folder.tone.ink,
                      weight: FontWeight.w800,
                      spacing: .5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    folder.title,
                    style: deskType(14, weight: FontWeight.w800, height: 1.27),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          folder.description,
          style: deskType(11.5, color: DeskColors.muted, height: 1.45),
        ),
        const SizedBox(height: 8),
        if (folder.items.isEmpty)
          const MetaLabel(
            Icons.folder_outlined,
            'No source material uploaded yet',
          )
        else
          for (final item in folder.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: DeskCard(
                color: const Color(0xfffaf9f6),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                onTap: () => item.open(context),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: violet.ink,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: deskType(12, weight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.description,
                            style: deskType(10, color: DeskColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      item.file != null
                          ? Icons.ios_share_outlined
                          : Icons.north_east,
                      color: violet.ink,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
        if (onPractice case final practice?)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                practice();
              },
              icon: const Icon(Icons.quiz_outlined, size: 17),
              label: const Text('Practice FN200'),
            ),
          ),
      ],
    ),
  );
}

class _Resource {
  const _Resource.guide(this.guide) : file = null;
  const _Resource.file(this.file) : guide = null;
  final StudyGuide? guide;
  final StudyFile? file;

  String get title => guide?.title ?? file!.title;
  String get description =>
      guide == null ? file!.description : 'Study guide · ${guide!.source}';

  void open(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    final document = file;
    if (document != null) {
      document.share(context);
      return;
    }
    final note = guide!;
    deskSheet(
      context,
      label: 'Study guide',
      title: note.title,
      children: [
        Text(note.source, style: deskType(11, color: DeskColors.muted)),
        const SizedBox(height: 9),
        Text(note.intro, style: deskType(13, height: 1.55)),
        const SizedBox(height: 11),
        for (final section in note.sections) ...[
          Text(
            section.title,
            style: deskType(13, color: violet.ink, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            section.body,
            style: deskType(12, color: DeskColors.muted, height: 1.55),
          ),
          const SizedBox(height: 10),
        ],
        DeskCard(
          color: violet.surface,
          border: violet.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Try it yourself',
                style: deskType(12, color: violet.ink, weight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                note.exercise,
                style: deskType(12, color: violet.ink, height: 1.55),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
