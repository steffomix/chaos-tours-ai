import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  PermissionHelper._();
  static final PermissionHelper instance = PermissionHelper._();

  /// Request fine location + coarse location.
  /// Returns true if granted.
  Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Request background location (must be called AFTER regular location
  /// permission is already granted — Android 10+ requires separate dialog).
  Future<bool> requestBackgroundLocationPermission() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Request POST_NOTIFICATIONS (Android 13+).
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Request READ_CALENDAR + WRITE_CALENDAR.
  Future<bool> requestCalendarPermission() async {
    final status = await Permission.calendarFullAccess.request();
    return status.isGranted;
  }

  /// Check whether all required runtime permissions are granted.
  Future<bool> hasAllPermissions() async {
    final location = await Permission.locationWhenInUse.isGranted;
    final background = await Permission.locationAlways.isGranted;
    final notification = await Permission.notification.isGranted;
    return location && background && notification;
  }

  /// Check whether fine location permission is granted (without requesting).
  Future<bool> hasLocationPermission() async {
    return Permission.locationWhenInUse.isGranted;
  }
}
