import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _keyGpsInterval = 'gps_interval_seconds';
  static const String _keyStayDetection = 'stay_detection_seconds';
  static const String _keyAutoPlace = 'auto_place_seconds';
  static const String _keyDefaultRadius = 'default_radius_meters';
  static const String _keyAutoCreate = 'auto_create_places';
  static const String _keyAutoPlaceGroup = 'auto_place_group_id';
  static const String _keyTrackingEnabled = 'tracking_enabled';

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

  /// Whether the background tracking service is enabled (default: false).
  bool get trackingEnabled => _p.getBool(_keyTrackingEnabled) ?? false;
  set trackingEnabled(bool v) => _p.setBool(_keyTrackingEnabled, v);
}
