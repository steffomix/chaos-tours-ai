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

  /// Returns a smoothed position from [rawPoints] using a moving-average with
  /// outlier rejection.
  ///
  /// Steps:
  /// 1. Compute the initial centroid of all points.
  /// 2. Discard points further than [outlierThresholdMeters] from that centroid.
  /// 3. Return the centroid of the remaining points.
  ///
  /// If all points are classified as outliers (pathological case) the most
  /// recent point ([rawPoints.last]) is returned unchanged.
  static ({double lat, double lng}) smoothedPosition(
    List<({double lat, double lng})> rawPoints, {
    double outlierThresholdMeters = 150.0,
  }) {
    assert(rawPoints.isNotEmpty);
    if (rawPoints.length == 1) return rawPoints.first;

    final c = centroid(rawPoints);
    final filtered = rawPoints
        .where(
          (p) =>
              distanceMeters(p.lat, p.lng, c.lat, c.lng) <=
              outlierThresholdMeters,
        )
        .toList();

    if (filtered.isEmpty) return rawPoints.last;
    return centroid(filtered);
  }
}
