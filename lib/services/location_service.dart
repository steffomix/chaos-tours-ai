import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const LocationSettings _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // metres between updates
  );

  Stream<Position> get positionStream =>
      Geolocator.getPositionStream(locationSettings: _settings);

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
