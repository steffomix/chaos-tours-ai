import 'dart:math';

class GeoUtils {
  GeoUtils._();

  static const double _earthRadiusMeters = 6371000.0;

  /// Haversine distance in meters between two coordinate pairs.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static double _toRad(double deg) => deg * pi / 180;

  /// Returns true if all [points] lie within [radiusMeters] of their centroid.
  static bool isCluster(
    List<({double lat, double lng})> points,
    double radiusMeters,
  ) {
    if (points.isEmpty) return false;
    if (points.length == 1) return true;

    final centroidLat =
        points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
    final centroidLng =
        points.map((p) => p.lng).reduce((a, b) => a + b) / points.length;

    for (final p in points) {
      if (distanceMeters(p.lat, p.lng, centroidLat, centroidLng) >
          radiusMeters) {
        return false;
      }
    }
    return true;
  }

  /// Returns the centroid (lat, lng) of a list of points.
  static ({double lat, double lng}) centroid(
    List<({double lat, double lng})> points,
  ) {
    assert(points.isNotEmpty);
    final lat =
        points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((p) => p.lng).reduce((a, b) => a + b) / points.length;
    return (lat: lat, lng: lng);
  }

  /// Returns the centroid of [rawPoints] as a smoothed position.
  static ({double lat, double lng}) smoothedPosition(
    List<({double lat, double lng})> rawPoints,
  ) {
    assert(rawPoints.isNotEmpty);
    if (rawPoints.length == 1) return rawPoints.first;
    return centroid(rawPoints);
  }
}
