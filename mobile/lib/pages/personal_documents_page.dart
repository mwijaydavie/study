import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design.dart';
import '../documents/personal_documents.dart';
import '../study_data.dart';
import '../ui/desk_motion.dart';

class PersonalDocumentsPage extends StatefulWidget {
  const PersonalDocumentsPage({
    super.key,
    required this.library,
    required this.clock,
  });
  final DocumentLibrary library;
  final CampusClock clock;

  @override
  State<PersonalDocumentsPage> createState() => _PersonalDocumentsPageState();
}

class _PersonalDocumentsPageState extends State<PersonalDocumentsPage> {
  List<PersonalDocument>? _documents;
  bool _busy = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _run(_reload);
  }

  Future<void> _reload() async {
    final files = await widget.library.list();
    if (mounted) setState(() => _documents = files);
  }

  String _errorMessage(String code) => switch (code) {
    'document_type' => 'Choose a PDF, DOC, DOCX, PPT or PPTX file.',
    'document_invalid' =>
      'This file does not match its format or is damaged. Try the original document.',
    'document_too_large' => 'This file is over 20 MiB.',
    'document_capacity' =>
      'My files is full (50 files or 200 MiB). Make room and try again.',
    'document_read' =>
      'Couldn’t read this file. Download it to this phone first, then try again.',
    'document_picker' => 'Couldn’t open the Android file picker.',
    'document_missing' =>
      'That StudyDesk copy is no longer available. Refresh the list.',
    'document_busy' || 'document_interrupted' =>
      'The file picker didn’t finish. Try again when it closes.',
    _ =>
      'Couldn’t complete the file action. The bundled materials and timetable are unchanged.',
  };

  Future<void> _run(Future<void> Function() work) async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await work();
    } on PlatformException catch (e) {
      if (mounted) setState(() => _problem = _errorMessage(e.code));
    } catch (_) {
      if (mounted) setState(() => _problem = _errorMessage('document_storage'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() => _run(() async {
    final file = await widget.library.pick();
    if (!mounted || file == null) return;
    setState(() => _documents = [file, ...?_documents]);
    if (ModalRoute.of(context)?.isCurrent == true) DeskHaptics.confirm();
    _notice('Saved on this phone. Nothing uploaded.');
  });

  Future<void> _open(PersonalDocument file) => _run(() async {
    if (!await widget.library.open(file.id)) {
      _notice(
        'No installed app could open this format. You can still share a copy.',
      );
    }
  });

  Future<void> _requestShare(PersonalDocument file) async {
    final allowed = await _confirm(
      'Share a copy?',
      'Only the file you choose will be shared. The receiving app may keep or upload its own copy.',
      'Choose app',
    );
    if (!mounted || !allowed) return;
    await _run(() async {
      if (!await widget.library.share(file.id))
        _notice('Couldn’t open the share sheet.');
    });
  }

  Future<void> _requestRemoval(PersonalDocument file) async {
    final allowed = await _confirm(
      'Remove from My files?',
      'This deletes the private StudyDesk copy. It does not delete the original or a copy you shared.',
      'Remove file',
    );
    if (!mounted || !allowed) return;
    await _run(() async {
      await widget.library.remove(file.id);
      if (!mounted) return;
      setState(
        () => _documents = _documents
            ?.where((item) => item.id != file.id)
            .toList(),
      );
      _notice('StudyDesk copy removed.');
    });
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Widget _fileCard(PersonalDocument file) => DeskCard(
    key: ValueKey(file.id),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DeskGlyph(
              file.formatLabel == 'PDF'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.insert_drive_file_outlined,
              tones: blue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name, style: deskType(14, weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    '${file.formatLabel} · ${file.sizeLabel} · On this phone',
                    style: deskType(11, color: DeskColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 3,
          children: [
            TextButton(
              onPressed: _busy ? null : () => _open(file),
              child: const Text('Open'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _requestShare(file),
              child: const Text('Share copy'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _requestRemoval(file),
              child: const Text('Remove'),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final files = _documents;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My files'),
        actions: [
          IconButton(
            tooltip: 'Refresh files',
            onPressed: _busy ? null : () => _run(_reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: DeskPage(
          clock: widget.clock,
          children: [
            DeskHero(
              title: 'My files',
              caption: 'PRIVATE · OFFLINE',
              subtitle:
                  'Keep your own study documents alongside the bundled materials.',
              meta: 'PDF · Word · PowerPoint',
              icon: Icons.folder_outlined,
              background: blue.surface,
              accent: blue.ink,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('pick-study-document'),
              onPressed: _busy || files == null ? null : _add,
              icon: const Icon(Icons.add),
              label: const Text('Add file'),
            ),
            const SizedBox(height: 8),
            const MetaLabel(
              Icons.lock_outline,
              'Files stay on this phone. Cloudinary backup is not connected.',
            ),
            const SizedBox(height: 7),
            const MetaLabel(
              Icons.info_outline,
              'PDF, DOC, DOCX, PPT and PPTX · up to 20 MiB each.',
            ),
            if (_busy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(
                semanticsLabel: 'Working on your files',
              ),
            ],
            const SizedBox(height: 12),
            if (_problem case final message?) ...[
              DeskCard(
                color: peach.surface,
                border: peach.surface,
                child: Text(message, style: deskType(12, color: peach.ink)),
              ),
              const SizedBox(height: 8),
            ],
            if (files != null)
              if (files.isEmpty)
                const DeskCard(
                  child: Text(
                    'No personal files yet. Choose a document already downloaded to your phone.',
                  ),
                )
              else
                for (final file in files) ...[
                  _fileCard(file),
                  const SizedBox(height: 8),
                ],
          ],
        ),
      ),
    );
  }
}
