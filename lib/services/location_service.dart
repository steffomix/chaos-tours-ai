import 'dart:io';

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
    if (!(Platform.isAndroid || Platform.isIOS)) {
      //52.326946385972256, 9.188932931787507
      return Position(
        altitudeAccuracy: 1.0,
        headingAccuracy: 1.0,
        longitude: 9.188932931787507,
        latitude: 52.326946385972256,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 1.0,
        heading: 1.0,
        speed: 1.0,
        speedAccuracy: 1.0,
      );
    }
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
      return null;
    }
  }
}
