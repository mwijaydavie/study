import 'dart:async';

import 'package:flutter/services.dart';
import 'package:studydesk/reminders/reminder_plan.dart';
import 'package:studydesk/reminders/reminders.dart';

class MemoryReminderPlatform implements ReminderPlatform {
  NotificationAccess access = NotificationAccess.notAsked;
  NotificationAccess afterRequest = NotificationAccess.allowed;
  final requests = <String, ReminderRequest>{};
  int permissionRequests = 0;
  int testNotifications = 0;
  int settingsOpened = 0;
  bool missing = false;
  bool failCancel = false;
  bool failSchedule = false;
  bool eventsArmed = true;
  ReminderTap? _tap;
  final _opens = StreamController<void>.broadcast();

  void tap(ReminderTap tap) {
    _tap = tap;
    _opens.add(null);
  }

  @override
  Stream<void> get opened => _opens.stream;

  @override
  Future<ReminderSnapshot> snapshot() async {
    if (missing) throw MissingPluginException();
    return ReminderSnapshot(
      access,
      List.of(requests.values),
      queuedEvents: {
        if (access == NotificationAccess.allowed && eventsArmed)
          for (final item in requests.values)
            if (item.isEvent) item.key,
      },
    );
  }

  @override
  Future<ReminderSnapshot> reconcile(List<String> keep) async {
    requests.removeWhere((id, _) => !keep.contains(id));
    return snapshot();
  }

  @override
  Future<NotificationAccess> requestPermission() async {
    permissionRequests++;
    return access = afterRequest;
  }

  @override
  Future<void> schedule(ReminderRequest request) async {
    if (failSchedule || access != NotificationAccess.allowed) {
      throw StateError('cannot schedule');
    }
    requests[request.key] = request;
  }

  @override
  Future<void> cancel(String key) async {
    if (failCancel) throw StateError('cannot cancel');
    requests.remove(key);
  }

  @override
  Future<void> cancelClassReminders() async {
    requests.removeWhere((_, item) => !item.isEvent);
  }

  @override
  Future<void> sendTest() async {
    testNotifications++;
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }

  @override
  Future<ReminderTap?> takeOpened() async {
    final tap = _tap;
    _tap = null;
    return tap;
  }

  @override
  void dispose() {
    unawaited(_opens.close());
  }
}
