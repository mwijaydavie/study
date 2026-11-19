import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../campus/campus_events.dart';
import 'reminder_plan.dart';

enum NotificationAccess {
  checking,
  notAsked,
  allowed,
  denied,
  blocked,
  unavailable,
}

class ReminderSnapshot {
  const ReminderSnapshot(
    this.access,
    this.requests, {
    this.queuedEvents = const {},
  });
  final NotificationAccess access;
  final List<ReminderRequest> requests;
  // Allowed, current-build event requests with Android alarm tokens. This
  // describes the last scheduler check, not a guarantee of delivery.
  final Set<String> queuedEvents;
}

class ReminderTap {
  const ReminderTap(this.sessionId, this.day, this.revision) : eventId = null;
  const ReminderTap.event(this.eventId, this.revision)
    : sessionId = null,
      day = null;
  final String? sessionId, day, eventId;
  final String revision;
}

typedef OpenedReminder = ({ClassOccurrence? classDate, CampusEvent? event});
typedef EventChange = ({bool saved, String message});

abstract interface class ReminderPlatform {
  Stream<void> get opened;
  Future<ReminderSnapshot> snapshot();
  Future<ReminderSnapshot> reconcile(List<String> keep);
  Future<NotificationAccess> requestPermission();
  Future<void> schedule(ReminderRequest request);
  Future<void> cancel(String key);
  Future<void> cancelClassReminders();
  Future<void> sendTest();
  Future<void> openSettings();
  Future<ReminderTap?> takeOpened();
  void dispose();
}

class AndroidReminderPlatform implements ReminderPlatform {
  AndroidReminderPlatform() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'reminderOpened') _opened.add(null);
    });
  }

  static const _channel = MethodChannel(
    'tz.altraware.studydesk/class_reminders',
  );
  final _opened = StreamController<void>.broadcast();

  @override
  Stream<void> get opened => _opened.stream;

  static NotificationAccess _access(Object? value) => switch (value) {
    'notAsked' => NotificationAccess.notAsked,
    'allowed' => NotificationAccess.allowed,
    'denied' => NotificationAccess.denied,
    'blocked' => NotificationAccess.blocked,
    _ => NotificationAccess.unavailable,
  };

  Future<ReminderSnapshot> _read(String method, [Object? arguments]) async {
    final value = await _channel.invokeMapMethod<Object?, Object?>(
      method,
      arguments,
    );
    final pending = value?['pending'];
    final queued = value?['queuedEvents'];
    if (pending is! List<Object?> || queued is! List<Object?>) {
      throw const FormatException('Invalid reminder snapshot');
    }
    return ReminderSnapshot(
      _access(value?['access']),
      pending
          .map(
            (item) =>
                ReminderRequest.fromPlatform(item as Map<Object?, Object?>),
          )
          .toList(),
      queuedEvents: queued.cast<String>().toSet(),
    );
  }

  @override
  Future<ReminderSnapshot> snapshot() => _read('snapshot');

  @override
  Future<ReminderSnapshot> reconcile(List<String> keep) =>
      _read('reconcile', keep);

  @override
  Future<NotificationAccess> requestPermission() async =>
      _access(await _channel.invokeMethod<String>('requestPermission'));

  @override
  Future<void> schedule(ReminderRequest request) =>
      _channel.invokeMethod<void>('schedule', request.toPlatform());

  @override
  Future<void> cancel(String key) => _channel.invokeMethod<void>('cancel', key);

  @override
  Future<void> cancelClassReminders() =>
      _channel.invokeMethod<void>('cancelClassReminders');

  @override
  Future<void> sendTest() => _channel.invokeMethod<void>('sendTest');

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');

  @override
  Future<ReminderTap?> takeOpened() async {
    final value = await _channel.invokeMapMethod<String, String>('takeOpened');
    if (value == null) return null;
    final revision = value['revision'];
    if (revision == null) return null;
    final eventId = value['eventId'];
    return eventId == null
        ? ReminderTap(value['sessionId'], value['day'], revision)
        : ReminderTap.event(eventId, revision);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    unawaited(_opened.close());
  }
}

class ReminderController extends ChangeNotifier {
  ReminderController({
    required this.plan,
    required ReminderPlatform platform,
    this.campusEvents,
    this.now = DateTime.now,
  }) : _platform = platform;

  final ClassReminderPlan plan;
  final CampusEventBook? campusEvents;
  final ReminderPlatform _platform;
  final DateTime Function() now;
  NotificationAccess _access = NotificationAccess.checking;
  List<ReminderRequest> _requests = const [];
  Set<String> _queuedEvents = const {};
  bool _busy = false;
  bool _refreshRequested = false;
  bool _disposed = false;
  bool _removedChangedClasses = false;

  NotificationAccess get access => _access;
  List<ReminderRequest> get pending =>
      List.unmodifiable(_requests.where((item) => !item.isEvent));

  ReminderRequest? pendingFor(CampusEvent event) {
    if (_access != NotificationAccess.allowed ||
        !_queuedEvents.contains(event.alertKey))
      return null;
    for (final item in _requests) {
      if (item.eventId == event.id && event.matches(item, now())) return item;
    }
    return null;
  }

  bool get busy => _busy;
  bool get removedChangedClasses => _removedChangedClasses;
  Stream<void> get opened => _platform.opened;

  String get statusLabel => switch (access) {
    NotificationAccess.checking => 'Checking Android settings…',
    NotificationAccess.notAsked =>
      'Off · notification permission not yet requested',
    NotificationAccess.denied => 'Notification permission denied',
    NotificationAccess.blocked => 'Notifications blocked in Android settings',
    NotificationAccess.unavailable => 'Reminder service unavailable',
    NotificationAccess.allowed =>
      pending.any((item) => !item.isTest)
          ? 'Notifications allowed · class reminders saved'
          : 'Off · no class reminders saved',
  };

  bool _keep(ReminderRequest item, DateTime instant) => item.isEvent
      ? (campusEvents?.find(item.eventId)?.matches(item, instant) ?? false)
      : plan.keep(item, instant);

  void _apply(ReminderSnapshot snapshot) {
    final instant = now();
    _access = snapshot.access;
    _requests = List.unmodifiable(
      snapshot.requests.where((item) => _keep(item, instant)).toList()
        ..sort((a, b) => a.target.compareTo(b.target)),
    );
    _queuedEvents = snapshot.queuedEvents;
  }

  Future<String?> _run(Future<String?> Function() work) async {
    if (_busy || _disposed) return null;
    _busy = true;
    notifyListeners();
    try {
      return await work();
    } catch (_) {
      _access = NotificationAccess.unavailable;
      return 'Couldn’t update Android reminders. Try refreshing; the timetable still works offline.';
    } finally {
      _busy = false;
      if (!_disposed) {
        notifyListeners();
        if (_refreshRequested) {
          _refreshRequested = false;
          unawaited(refresh());
        }
      }
    }
  }

  Future<String?> refresh() async {
    if (_busy && !_disposed) {
      // Returning from system settings or a permission prompt can overlap a save.
      _refreshRequested = true;
      return null;
    }
    return _run(_reconcile);
  }

  Future<String?> _reconcile() async {
    final original = await _platform.snapshot();
    final instant = now();
    final keep = <String>[];
    for (final item in original.requests) {
      if (_keep(item, instant)) {
        keep.add(item.key);
      } else if (!item.isEvent &&
          !item.isTest &&
          item.expires.isAfter(instant)) {
        _removedChangedClasses = true;
      }
    }
    _apply(await _platform.reconcile(keep));
    await _restoreEventPreferences();
    return null;
  }

  bool _eventWithinHorizon(ReminderRequest item, DateTime instant) =>
      item.target.isAfter(instant) &&
      !item.target.isAfter(instant.add(eventReminderHorizon));

  int get _eventCount => _requests.where((item) => item.isEvent).length;

  // Restores saved, explicitly opted-in preferences after permission is granted,
  // a target moves into range, or a previous write was interrupted. No prompt.
  Future<void> _restoreEventPreferences() async {
    final book = campusEvents;
    if (book == null ||
        !book.available ||
        _access != NotificationAccess.allowed)
      return;
    final instant = now();
    final savedKeys = {for (final item in _requests) item.key};
    final candidates =
        book.events
            .map((event) => event.notification)
            .nonNulls
            .where(
              (item) =>
                  !_queuedEvents.contains(item.key) &&
                  _eventWithinHorizon(item, instant),
            )
            .toList()
          ..sort((a, b) => a.target.compareTo(b.target));
    var remaining = eventReminderCapacity - _eventCount;
    var wrote = false;
    for (final item in candidates) {
      if (_disposed) break;
      final replacing = savedKeys.contains(item.key);
      if (!replacing && remaining <= 0) continue;
      try {
        await _platform.schedule(item);
        if (!replacing) remaining--;
        wrote = true;
      } catch (_) {
        // Keep the preference; do not show an alert as pending if Android rejected it.
      }
    }
    if (wrote) _apply(await _platform.snapshot());
  }

  Future<bool> _allow({bool ask = true}) async {
    _apply(await _platform.snapshot());
    if (ask && _access == NotificationAccess.notAsked) {
      _access = await _platform.requestPermission();
    }
    return _access == NotificationAccess.allowed;
  }

  String get _notAllowed =>
      'No reminder added. $statusLabel. Check Android notification settings.';

  Future<String?> setClassReminder(
    ClassOccurrence occurrence,
    int lead,
  ) => _run(() async {
    if (plan.create(occurrence, lead, now()) == null) {
      return 'That reminder time has passed or the class changed. Choose another date or lead time.';
    }
    if (!await _allow()) return _notAllowed;
    final request = plan.create(occurrence, lead, now());
    if (request == null)
      return 'That reminder time has passed. Choose a later time.';
    await _platform.schedule(request);
    _apply(await _platform.snapshot());
    return 'Class reminder saved. Android may deliver after the target time.';
  });

  Future<String?> sendTest({required bool delayed}) => _run(() async {
    if (!await _allow()) return _notAllowed;
    if (delayed) {
      final target = now().toUtc().add(const Duration(minutes: 1));
      await _platform.schedule(
        ReminderRequest(
          key: 'test',
          target: target,
          expires: target.add(const Duration(hours: 1)),
          title: 'StudyDesk reminder test',
          body: 'This is a test notification, not a class reminder.',
        ),
      );
      _apply(await _platform.snapshot());
      return 'Test scheduled with a target one minute from now. Lock the phone; Android can delay delivery.';
    }
    await _platform.sendTest();
    return 'Test sent to Android. Check the notification shade.';
  });

  Future<String?> remove(String key) => _run(() async {
    if (key.startsWith('event:'))
      return 'Edit the notification from Campus events.';
    await _platform.cancel(key);
    _apply(await _platform.snapshot());
    return 'Reminder removed.';
  });

  Future<String?> removeAll() => _run(() async {
    await _platform.cancelClassReminders();
    _apply(await _platform.snapshot());
    return 'Class and test reminders removed. Campus events were not changed.';
  });

  Future<String?> openSettings() => _run(() async {
    await _platform.openSettings();
    return null;
  });

  Future<EventChange> saveEvent(CampusEvent event) =>
      _changeEvent(event.id, event);

  Future<EventChange> deleteEvent(String id) => _changeEvent(id, null);

  Future<EventChange> _changeEvent(String id, CampusEvent? next) async {
    var saved = false;
    final message = await _run(() async {
      final book = campusEvents;
      if (book == null || !book.available)
        return 'Event storage is unavailable. Nothing changed.';
      if (next != null && !book.canSave(next))
        return 'Event storage is full. Remove an older event first.';
      final previous = book.find(id);
      if (next == null && previous == null)
        return 'This event is no longer saved.';

      if (previous != null &&
          previous.notification != null &&
          previous.revision != next?.revision) {
        // Cancel before changing the stored event. If Android cannot cancel an
        // older request, do not apply an edit or delete with that alert still armed.
        try {
          await _platform.cancel(previous.alertKey);
        } catch (_) {
          _access = NotificationAccess.unavailable;
          return 'Couldn’t cancel the old notification. The event was not changed. Refresh and try again.';
        }
        _requests = List.unmodifiable(
          _requests.where((item) => item.eventId != id),
        );
        _queuedEvents = {..._queuedEvents}..remove(previous.alertKey);
      }
      try {
        if (next == null) {
          await book.remove(id);
        } else {
          await book.save(next);
        }
      } catch (_) {
        return 'Couldn’t write to device storage. The event was not changed. Reopen StudyDesk to check its notification.';
      }
      saved = true;
      if (next == null)
        return 'Event deleted from StudyDesk. Any copy in Calendar is unchanged.';
      final request = next.notification;
      if (request == null)
        return 'Event saved on this phone. No StudyDesk notification selected.';
      try {
        // An unchanged inexact alert may still be pending after its target.
        final allowed = await _allow(ask: _eventWithinHorizon(request, now()));
        if (pendingFor(next) != null) {
          return 'Event saved. Its StudyDesk notification is pending.';
        }
        if (!_eventWithinHorizon(request, now())) {
          return 'Event saved. No notification queued: its target has passed or is more than 365 days away.';
        }
        if (!allowed) {
          return 'Event saved. StudyDesk notification is not queued. Check Android notification settings.';
        }
        if (_eventCount >= eventReminderCapacity &&
            !_requests.any((item) => item.key == request.key)) {
          return 'Event saved. The Android event reminder list is full (32).';
        }
        await _platform.schedule(request);
        _apply(await _platform.snapshot());
        return pendingFor(next) != null
            ? 'Event saved. StudyDesk notification queued; Android may delay it.'
            : 'Event saved. Could not verify that its Android notification is queued.';
      } catch (_) {
        _access = NotificationAccess.unavailable;
        return 'Event saved. Could not verify its Android notification.';
      }
    });
    return (
      saved: saved,
      message: message ?? 'StudyDesk is updating reminders. Try again shortly.',
    );
  }

  Future<OpenedReminder?> takeOpenedReminder() async {
    try {
      final tap = await _platform.takeOpened();
      if (tap == null) return null;
      if (tap.eventId != null) {
        final event = campusEvents?.find(tap.eventId);
        if (event != null && event.revision == tap.revision)
          return (classDate: null, event: event);
      } else {
        final date = plan.openFromTap(tap.sessionId, tap.day, tap.revision);
        if (date != null) return (classDate: date, event: null);
      }
    } catch (_) {
      // A missing platform or obsolete deep link doesn't block the offline app.
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _platform.dispose();
    super.dispose();
  }
}
