import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_point.dart';
import '../models/tour.dart';
import '../services/database_service.dart';

/// Keys used when communicating via SendPort.
class FgTaskKeys {
  static const String startTour = 'start_tour';
  static const String stopTour = 'stop_tour';
  static const String position = 'position';
  static const String tourId = 'tour_id';
}

/// Task handler that runs in the foreground service isolate.
class GpsForegroundTaskHandler extends TaskHandler {
  int? _activeTourId;
  StreamSubscription<Position>? _positionSub;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onDataFromMain);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat — nothing needed; GPS driven by stream.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positionSub?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_onDataFromMain);
  }

  void _onDataFromMain(Object data) {
    if (data is Map) {
      final cmd = data['cmd'] as String?;
      if (cmd == FgTaskKeys.startTour) {
        _activeTourId = data[FgTaskKeys.tourId] as int?;
        _startTracking();
      } else if (cmd == FgTaskKeys.stopTour) {
        _stopTracking();
      }
    }
  }

  void _startTracking() {
    _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) async {
          final tourId = _activeTourId;
          if (tourId == null) return;

          final point = LocationPoint(
            tourId: tourId,
            lat: position.latitude,
            lng: position.longitude,
            timestamp: position.timestamp.millisecondsSinceEpoch,
          );
          await DatabaseService.instance.insertLocationPoint(point);

          // Send position back to UI
          FlutterForegroundTask.sendDataToMain({
            'cmd': FgTaskKeys.position,
            'lat': position.latitude,
            'lng': position.longitude,
            'ts': position.timestamp.millisecondsSinceEpoch,
          });
        });
  }

  void _stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _activeTourId = null;
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
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWifiLock: false,
      ),
    );
  }

  static Future<ServiceRequestResult> startService(Tour tour) async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    }
    return FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: 'Chaos Tours',
      notificationText: 'Tour "${tour.name}" wird aufgezeichnet…',
      callback: _startGpsTask,
    );
  }

  static Future<ServiceRequestResult> stopService() {
    return FlutterForegroundTask.stopService();
  }

  static void sendStartTour(int tourId) {
    FlutterForegroundTask.sendDataToTask({
      'cmd': FgTaskKeys.startTour,
      FgTaskKeys.tourId: tourId,
    });
  }

  static void sendStopTour() {
    FlutterForegroundTask.sendDataToTask({'cmd': FgTaskKeys.stopTour});
  }

  static void Function(Object)? _positionCallbackWrapper;

  static void addPositionListener(
    void Function(Map<dynamic, dynamic>) callback,
  ) {
    _positionCallbackWrapper = (Object data) {
      if (data is Map && data['cmd'] == FgTaskKeys.position) {
        callback(data);
      }
    };
    FlutterForegroundTask.addTaskDataCallback(_positionCallbackWrapper!);
  }

  static void removePositionListener(
    void Function(Map<dynamic, dynamic>) callback,
  ) {
    if (_positionCallbackWrapper != null) {
      FlutterForegroundTask.removeTaskDataCallback(_positionCallbackWrapper!);
      _positionCallbackWrapper = null;
    }
  }
}

/// Entry point registered with FlutterForegroundTask — must be top-level.
@pragma('vm:entry-point')
void _startGpsTask() {
  FlutterForegroundTask.setTaskHandler(GpsForegroundTaskHandler());
}
