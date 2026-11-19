import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class StudyFile {
  const StudyFile(this.name, this.title, this.description, this.mime);

  final String name;
  final String title;
  final String description;
  final String mime;

  String get asset => 'assets/downloads/$name';

  Future<void> share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize && !box.size.isEmpty
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(1, 1, 1, 1);
    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await SharePlus.instance.share(
        ShareParams(
          subject: title,
          files: [XFile.fromData(bytes, mimeType: mime)],
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Couldn’t open the share sheet on this device.'),
          ),
        );
      }
    }
  }
}

const timetableFile = StudyFile(
  'bit-year-2-timetable.pdf',
  'BIT Year 2 weekly timetable',
  'Print-friendly · PDF',
  'application/pdf',
);
const plannerFile = StudyFile(
  'bit-year-2-study-planner.docx',
  'BIT Year 2 study planner',
  'Editable Word document · DOCX',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
);
const slidesFile = StudyFile(
  'is274-ooad-revision.pptx',
  'OOAD revision slides',
  'Editable PowerPoint · PPTX',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
);
