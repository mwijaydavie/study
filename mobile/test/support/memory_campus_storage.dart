import 'package:studydesk/campus/campus_events.dart';

class MemoryCampusStorage implements CampusEventStorage {
  MemoryCampusStorage({this.snapshot});

  String? snapshot;
  bool failWrites = false;
  Future<void> Function()? beforeWrite;

  @override
  Future<String?> readEvents() async => snapshot;

  @override
  Future<void> writeEvents(String snapshot) async {
    await beforeWrite?.call();
    if (failWrites) throw StateError('disk unavailable');
    this.snapshot = snapshot;
  }
}
