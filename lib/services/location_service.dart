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
  static RecentGPSPoint? lastPoint;

  static const LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // metres between updates
  );

  Stream<Position> get positionStream =>
      Geolocator.getPositionStream(locationSettings: _settings);

  Future<Position?> getCurrentPosition() async {
    final interval = SettingsService.instance.gpsIntervalSeconds * 1000;
    if (lastPoint != null &&
        DateTime.now().difference(lastPoint!.timestamp).inMilliseconds <
            interval * 0.8) {
      return lastPoint!.position;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      lastPoint = RecentGPSPoint(position, DateTime.now());
      return position;
    } catch (_) {
      return null;
    }
  }
}
