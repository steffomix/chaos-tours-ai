import 'package:shared_preferences/shared_preferences.dart';

import '../models/aktivitaet.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _keyGpsInterval = 'gps_interval_seconds';
  static const String _keyStayDetection = 'stay_detection_seconds';
  static const String _keyAutoPlace = 'auto_place_seconds';
  static const String _keyDefaultRadius = 'default_radius_meters';
  static const String _keyAutoCreate = 'auto_create_places';
  static const String _keyAutoPlaceGroup = 'auto_place_group_id';
  static const String _keyAutoPlacePlaceType = 'auto_place_place_type';
  static const String _keyTrackingEnabled = 'tracking_enabled';
  static const String _keyActiveAktivitaetId = 'active_aktivitaet_id';
  static const String _keyShowForbiddenPlaces = 'show_forbidden_places';
  static const String _keyShowTrackingPoints = 'show_tracking_points';
  static const String _keyTrackingPointRadius = 'tracking_point_radius';
  static const String _keyGpsSmoothingPoints = 'gps_smoothing_points';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    assert(_prefs != null, 'SettingsService.init() must be called before use');
    return _prefs!;
  }

  /// GPS sampling interval in seconds (default: 15).
  int get gpsIntervalSeconds => _p.getInt(_keyGpsInterval) ?? 15;
  set gpsIntervalSeconds(int v) => _p.setInt(_keyGpsInterval, v.clamp(5, 120));

  /// Duration in seconds for stay detection at known places (default: 180 = 3 min).
  int get stayDetectionSeconds => _p.getInt(_keyStayDetection) ?? 180;
  set stayDetectionSeconds(int v) =>
      _p.setInt(_keyStayDetection, v.clamp(60, 600));

  /// Duration in seconds before auto-creating a place (default: 900 = 15 min).
  int get autoPlaceSeconds => _p.getInt(_keyAutoPlace) ?? 900;
  set autoPlaceSeconds(int v) => _p.setInt(_keyAutoPlace, v.clamp(300, 3600));

  /// Default radius in meters for stay detection (default: 50).
  double get defaultRadiusMeters => _p.getDouble(_keyDefaultRadius) ?? 50.0;
  set defaultRadiusMeters(double v) =>
      _p.setDouble(_keyDefaultRadius, v.clamp(10.0, 500.0));

  /// Whether to automatically create places for unknown stays (default: true).
  bool get autoCreatePlaces => _p.getBool(_keyAutoCreate) ?? true;
  set autoCreatePlaces(bool v) => _p.setBool(_keyAutoCreate, v);

  /// Group ID for automatically created places (nullable).
  int? get autoPlaceGroupId => _p.getInt(_keyAutoPlaceGroup);
  set autoPlaceGroupId(int? v) {
    if (v == null) {
      _p.remove(_keyAutoPlaceGroup);
    } else {
      _p.setInt(_keyAutoPlaceGroup, v);
    }
  }

  /// PlaceType index for automatically created places (default: 1 = private).
  int get autoPlacePlaceTypeIndex => _p.getInt(_keyAutoPlacePlaceType) ?? 1;
  set autoPlacePlaceTypeIndex(int v) => _p.setInt(_keyAutoPlacePlaceType, v);

  /// Whether the background tracking service is enabled (default: false).
  bool get trackingEnabled => _p.getBool(_keyTrackingEnabled) ?? false;
  set trackingEnabled(bool v) => _p.setBool(_keyTrackingEnabled, v);

  /// Whether forbidden places are shown in the places list (default: false).
  bool get showForbiddenPlaces => _p.getBool(_keyShowForbiddenPlaces) ?? false;
  set showForbiddenPlaces(bool v) => _p.setBool(_keyShowForbiddenPlaces, v);

  /// Whether tracking points are shown on the map (default: true).
  bool get showTrackingPoints => _p.getBool(_keyShowTrackingPoints) ?? true;
  set showTrackingPoints(bool v) => _p.setBool(_keyShowTrackingPoints, v);

  /// Radius in meters for tracking point circles on the map (default: 2.0).
  double get trackingPointRadius =>
      _p.getDouble(_keyTrackingPointRadius) ?? 2.0;
  set trackingPointRadius(double v) =>
      _p.setDouble(_keyTrackingPointRadius, v.clamp(1.0, 20.0));

  /// Number of GPS points to average for smoothing (1 = disabled, default: 3).
  int get gpsSmoothingPoints => _p.getInt(_keyGpsSmoothingPoints) ?? 3;
  set gpsSmoothingPoints(int v) =>
      _p.setInt(_keyGpsSmoothingPoints, v.clamp(1, 10));

  // ── Aktivitaet binding ───────────────────────────────────────────────────

  /// The ID of the currently selected [Aktivitaet].
  int? get activeAktivitaetId => _p.getInt(_keyActiveAktivitaetId);
  set activeAktivitaetId(int? v) {
    if (v == null) {
      _p.remove(_keyActiveAktivitaetId);
    } else {
      _p.setInt(_keyActiveAktivitaetId, v);
    }
  }

  /// Copies all settings from [a] into SharedPreferences so that the rest of
  /// the app picks them up synchronously, and remembers [a.id] as the active
  /// Aktivitaet.
  void applyAktivitaet(Aktivitaet a) {
    gpsIntervalSeconds = a.gpsIntervalSeconds;
    stayDetectionSeconds = a.stayDetectionSeconds;
    autoPlaceSeconds = a.autoPlaceSeconds;
    defaultRadiusMeters = a.defaultRadiusMeters;
    autoCreatePlaces = a.autoCreatePlaces;
    autoPlaceGroupId = a.autoPlaceGroupId;
    autoPlacePlaceTypeIndex = a.autoPlacePlaceTypeIndex;
    activeAktivitaetId = a.id;
  }

  /// Builds an [Aktivitaet] snapshot of the current SharedPreferences values.
  /// Useful when saving the settings screen back to DB.
  Aktivitaet snapshotAsAktivitaet({required int id, required String name}) {
    return Aktivitaet(
      id: id,
      name: name,
      gpsIntervalSeconds: gpsIntervalSeconds,
      stayDetectionSeconds: stayDetectionSeconds,
      autoPlaceSeconds: autoPlaceSeconds,
      defaultRadiusMeters: defaultRadiusMeters,
      autoCreatePlaces: autoCreatePlaces,
      autoPlaceGroupId: autoPlaceGroupId,
      autoPlacePlaceTypeIndex: autoPlacePlaceTypeIndex,
    );
  }
}
