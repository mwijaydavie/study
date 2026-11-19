import 'package:flutter/services.dart';

/// Stable local identity and metadata, independent of a storage/backup provider.
/// The file's Android path and original provider URI are never exposed to Dart.
class PersonalDocument {
  const PersonalDocument({
    required this.id,
    required this.name,
    required this.mime,
    required this.bytes,
  });

  factory PersonalDocument.fromPlatform(Map<Object?, Object?> entry) =>
      PersonalDocument(
        id: entry['id'] as String,
        name: entry['name'] as String,
        mime: entry['mime'] as String,
        bytes: entry['size'] as int,
      );

  final String id, name, mime;
  final int bytes;
  String get formatLabel => name.split('.').last.toUpperCase();
  String get sizeLabel => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB'
      : bytes >= 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KiB'
      : '$bytes B';
}

abstract interface class DocumentLibrary {
  Future<List<PersonalDocument>> list();

  /// Android picker + private copy. Null means the picker did not select a file.
  Future<PersonalDocument?> pick();
  Future<bool> open(String id);
  Future<bool> share(String id);
  Future<void> remove(String id);
}

class AndroidDocumentLibrary implements DocumentLibrary {
  const AndroidDocumentLibrary();
  static const _channel = MethodChannel('tz.altraware.studydesk/documents');

  @override
  Future<List<PersonalDocument>> list() async {
    final entries = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'list',
    );
    if (entries == null) throw const FormatException('No document list');
    return entries.map(PersonalDocument.fromPlatform).toList(growable: false);
  }

  @override
  Future<PersonalDocument?> pick() async {
    final chosen = await _channel.invokeMapMethod<Object?, Object?>('pick');
    return chosen == null ? null : PersonalDocument.fromPlatform(chosen);
  }

  @override
  Future<bool> open(String id) async =>
      await _channel.invokeMethod<bool>('open', id) ?? false;

  @override
  Future<bool> share(String id) async =>
      await _channel.invokeMethod<bool>('share', id) ?? false;

  @override
  Future<void> remove(String id) => _channel.invokeMethod<void>('remove', id);
}
