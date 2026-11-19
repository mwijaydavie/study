import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studydesk/design.dart';
import 'package:studydesk/documents/personal_documents.dart';
import 'package:studydesk/main.dart';
import 'package:studydesk/study_data.dart';
import 'package:studydesk/workspace.dart';

const _dummy = PersonalDocument(
  id: '0123456789abcdef0123456789abcdef',
  name: 'Practice slides.pptx',
  mime:
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  bytes: 4096,
);

class _LocalFiles implements DocumentLibrary {
  final _files = <PersonalDocument>[];
  PersonalDocument? nextFile;
  bool reject = false;
  String? opened, shared, removed;

  @override
  Future<List<PersonalDocument>> list() async => List.of(_files);

  @override
  Future<PersonalDocument?> pick() async {
    if (reject) throw PlatformException(code: 'document_too_large');
    if (nextFile case final document?) _files.add(document);
    return nextFile;
  }

  @override
  Future<bool> open(String id) async {
    opened = id;
    return false;
  }

  @override
  Future<bool> share(String id) async {
    shared = id;
    return true;
  }

  @override
  Future<void> remove(String id) async {
    removed = id;
    _files.removeWhere((file) => file.id == id);
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StudyData data;
  setUpAll(() async {
    data = await StudyData.load(rootBundle);
  });

  test(
    'the Android bridge decodes limited metadata and returns null on picker cancel',
    () async {
      const channel = MethodChannel('tz.altraware.studydesk/documents');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final entry = <String, Object>{
        'id': _dummy.id,
        'name': _dummy.name,
        'mime': _dummy.mime,
        'size': _dummy.bytes,
      };
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => switch (call.method) {
          'list' => [entry],
          'pick' => null,
          _ => throw MissingPluginException(),
        },
      );
      const library = AndroidDocumentLibrary();
      final file = (await library.list()).single;
      expect(file.id, _dummy.id);
      expect(file.name, _dummy.name);
      expect(file.formatLabel, 'PPTX');
      expect(file.sizeLabel, '4.0 KiB');
      expect(await library.pick(), isNull);
    },
  );

  testWidgets(
    'Materials supports local pick, cancel, share confirmation and remove',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final files = _LocalFiles();
      final workspace = Workspace(null);
      addTearDown(workspace.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: deskTheme(),
          home: DeskHome(
            data: data,
            workspace: workspace,
            documents: files,
            now: () => DateTime.utc(2026, 11, 19, 5),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Materials'));
      await _tap(tester, find.byKey(const Key('personal-files-entry')));
      final add = find.byKey(const Key('pick-study-document'));
      await _tap(tester, add);
      expect(find.textContaining('No personal files yet'), findsOneWidget);
      expect(find.textContaining('Nothing uploaded'), findsNothing);
      files.reject = true;
      await _tap(tester, add);
      expect(find.textContaining('over 20 MiB'), findsOneWidget);
      expect(await files.list(), isEmpty);
      files.reject = false;
      files.nextFile = _dummy;
      await _tap(tester, add);
      expect(find.text(_dummy.name), findsOneWidget);
      expect(find.textContaining('Nothing uploaded'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Open'));
      expect(files.opened, _dummy.id);
      expect(find.textContaining('No installed app'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Share copy'));
      await _tap(tester, find.text('Cancel'));
      expect(files.shared, isNull);
      await _tap(tester, find.text('Share copy'));
      await _tap(tester, find.text('Choose app'));
      expect(files.shared, _dummy.id);
      await _tap(tester, find.text('Remove'));
      await _tap(tester, find.text('Remove file'));
      expect(files.removed, _dummy.id);
      expect(find.text(_dummy.name), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
