import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../services/settings_service.dart';
import '../services/tracking_engine.dart';

/// Keys used when communicating via SendPort.
class FgTaskKeys {
  static const String setTracking = 'set_tracking';
  static const String endStay = 'end_stay';
  static const String position = 'position';
  static const String enabled = 'enabled';
  static const String trackingStatus = 'tracking_status';
  static const String stayChanged = 'stay_changed';
}

/// Task handler that runs in the foreground service isolate.
class GpsForegroundTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionSub;
  bool _trackingEnabled = false;
  final TrackingEngine _engine = TrackingEngine();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await SettingsService.instance.init();
    // Clear any stale force-end flag left from a previous session.
    SettingsService.instance.forceEndStayPending = false;
    _trackingEnabled = SettingsService.instance.trackingEnabled;
    if (_trackingEnabled) {
      await _engine.initialize();
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Reload SharedPreferences from disk so we see writes from the main isolate.
    await SettingsService.instance.reload();

    // Sync tracking-enabled state from SharedPreferences (SendPort is unreliable).
    final wantTracking = SettingsService.instance.trackingEnabled;
    if (wantTracking != _trackingEnabled) {
      await _setTracking(wantTracking);
    }

    // Check for a force-end request posted via SharedPreferences.
    if (SettingsService.instance.forceEndStayPending) {
      SettingsService.instance.forceEndStayPending = false;
      await _engine.forceEndCurrentStay();
    }

    if (!_trackingEnabled) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final result = await _engine.onNewPoint(
        position.latitude,
        position.longitude,
        position.timestamp.millisecondsSinceEpoch,
      );

      // Update notification text
      if (result.notificationText != null) {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Chaos Tours',
          notificationText: result.notificationText!,
        );
      }

      // Notify main isolate
      FlutterForegroundTask.sendDataToMain({
        'cmd': FgTaskKeys.trackingStatus,
        'status': result.status.name,
        'stay_id': result.currentStay?.id,
        'place_name': result.currentPlace?.name,
        'address': result.currentStay?.address,
        'lat': position.latitude,
        'lng': position.longitude,
        'ts': position.timestamp.millisecondsSinceEpoch,
      });
    } catch (_) {
      // GPS unavailable — silently skip this tick
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positionSub?.cancel();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final cmd = data['cmd'] as String?;
      switch (cmd) {
        case FgTaskKeys.setTracking:
          final enabled = data[FgTaskKeys.enabled] as bool? ?? false;
          _setTracking(enabled);
        case FgTaskKeys.endStay:
          // Legacy path kept for completeness; primary path is SharedPreferences.
          SettingsService.instance.forceEndStayPending = true;
      }
    }
  }

  Future<void> _setTracking(bool enabled) async {
    _trackingEnabled = enabled;
    SettingsService.instance.trackingEnabled = enabled;
    if (enabled) {
      await _engine.initialize();
    } else {
      await _engine.stopTracking();
    }
  }
}

/// Static helpers to initialise, start, and stop the foreground service.
class ForegroundServiceManager {
  ForegroundServiceManager._();

  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'chaos_tours_gps',
        channelName: 'GPS Tracking',
        channelDescription: 'Chaos Tours GPS-Aufzeichnung läuft.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        allowWifiLock: false,
      ),
    );
  }

  static Future<ServiceRequestResult> startService({
    required String notificationText,
  }) async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    }
    return FlutterForegroundTask.startService(
      serviceId: 1001,
      serviceTypes: [ForegroundServiceTypes.location],
      notificationTitle: 'Chaos Tours',
      notificationText: notificationText,
      callback: _startGpsTask,
    );
  }

  static Future<ServiceRequestResult> stopService() {
    return FlutterForegroundTask.stopService();
  }

  // ── Auto-Tracking Commands ───────────────────────────────────────────────

  static void sendSetTracking(bool enabled) {
    FlutterForegroundTask.sendDataToTask({
      'cmd': FgTaskKeys.setTracking,
      FgTaskKeys.enabled: enabled,
    });
  }

  static void sendForceEndStay() {
    // Write the flag via SharedPreferences — the task isolate reads it on the
    // next onRepeatEvent tick. The SendPort message is sent as a fallback for
    // cases where the message mechanism happens to work.
    SettingsService.instance.forceEndStayPending = true;
    FlutterForegroundTask.sendDataToTask({'cmd': FgTaskKeys.endStay});
  }

  // ── Listeners ────────────────────────────────────────────────────────────

  static final Map<void Function(Map), void Function(Object)>
  _dataCallbackWrappers = {};

  static void addDataListener(void Function(Map<dynamic, dynamic>) callback) {
    // Guard against duplicate registration for the same callback.
    if (_dataCallbackWrappers.containsKey(callback)) return;
    final wrapper = (Object data) {
      if (data is Map) callback(data);
    };
    _dataCallbackWrappers[callback] = wrapper;
    FlutterForegroundTask.addTaskDataCallback(wrapper);
  }

  static void removeDataListener(
    void Function(Map<dynamic, dynamic>) callback,
  ) {
    final wrapper = _dataCallbackWrappers.remove(callback);
    if (wrapper != null) {
      FlutterForegroundTask.removeTaskDataCallback(wrapper);
    }
  }
}

/// Entry point registered with FlutterForegroundTask — must be top-level.
@pragma('vm:entry-point')
void _startGpsTask() {
  FlutterForegroundTask.setTaskHandler(GpsForegroundTaskHandler());
}
