import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'settings_service.dart';

class RecentGPSPoint {
  final Position position;
  final DateTime timestamp;

  RecentGPSPoint(this.position, this.timestamp);
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();
  static RecentGPSPoint? _lastPoint;

  Future<Position?> getCurrentPosition() async {
    final interval = SettingsService.instance.gpsIntervalSeconds * 1000;
    if (_lastPoint != null &&
        DateTime.now().difference(_lastPoint!.timestamp).inMilliseconds <
            interval * 0.8) {
      return _lastPoint!.position;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _lastPoint = RecentGPSPoint(position, DateTime.now());
      return position;
    } catch (_) {
      // debug on linux without gps device
      if (kDebugMode && !(Platform.isAndroid || Platform.isIOS)) {
        // 52.323859980243974, 9.204868209524584
        return Position(
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
          longitude: 9.204868209524584,
          latitude: 52.323859980243974,
          timestamp: DateTime.now(),
          accuracy: 1.0,
          altitude: 1.0,
          heading: 1.0,
          speed: 1.0,
          speedAccuracy: 1.0,
        );
      }
      return null;
    }
  }
}
