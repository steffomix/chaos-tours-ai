/// A named settings profile. At most one is "active" at a time;
/// its settings are used by the tracking engine and are also
/// shown/edited in the Settings screen.
class Aktivitaet {
  final int? id;
  final String name;
  final int gpsIntervalSeconds;
  final int stayDetectionSeconds;
  final int autoPlaceSeconds;
  final double defaultRadiusMeters;
  final bool autoCreatePlaces;
  final int? autoPlaceGroupId;

  /// PlaceType index used for automatically created places (default: 1 = private).
  final int autoPlacePlaceTypeIndex;

  const Aktivitaet({
    this.id,
    required this.name,
    this.gpsIntervalSeconds = 15,
    this.stayDetectionSeconds = 180,
    this.autoPlaceSeconds = 900,
    this.defaultRadiusMeters = 50.0,
    this.autoCreatePlaces = true,
    this.autoPlaceGroupId,
    this.autoPlacePlaceTypeIndex = 1,
  });

  factory Aktivitaet.fromMap(Map<String, dynamic> map) {
    return Aktivitaet(
      id: map['id'] as int?,
      name: map['name'] as String,
      gpsIntervalSeconds: map['gps_interval_seconds'] as int? ?? 15,
      stayDetectionSeconds: map['stay_detection_seconds'] as int? ?? 180,
      autoPlaceSeconds: map['auto_place_seconds'] as int? ?? 900,
      defaultRadiusMeters:
          (map['default_radius_meters'] as num?)?.toDouble() ?? 50.0,
      autoCreatePlaces: (map['auto_create_places'] as int? ?? 1) == 1,
      autoPlaceGroupId: map['auto_place_group_id'] as int?,
      autoPlacePlaceTypeIndex: map['auto_place_place_type'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'gps_interval_seconds': gpsIntervalSeconds,
      'stay_detection_seconds': stayDetectionSeconds,
      'auto_place_seconds': autoPlaceSeconds,
      'default_radius_meters': defaultRadiusMeters,
      'auto_create_places': autoCreatePlaces ? 1 : 0,
      if (autoPlaceGroupId != null) 'auto_place_group_id': autoPlaceGroupId,
      'auto_place_place_type': autoPlacePlaceTypeIndex,
    };
  }

  Aktivitaet copyWith({
    int? id,
    String? name,
    int? gpsIntervalSeconds,
    int? stayDetectionSeconds,
    int? autoPlaceSeconds,
    double? defaultRadiusMeters,
    bool? autoCreatePlaces,
    int? autoPlaceGroupId,
    bool clearAutoPlaceGroupId = false,
    int? autoPlacePlaceTypeIndex,
  }) {
    return Aktivitaet(
      id: id ?? this.id,
      name: name ?? this.name,
      gpsIntervalSeconds: gpsIntervalSeconds ?? this.gpsIntervalSeconds,
      stayDetectionSeconds: stayDetectionSeconds ?? this.stayDetectionSeconds,
      autoPlaceSeconds: autoPlaceSeconds ?? this.autoPlaceSeconds,
      defaultRadiusMeters: defaultRadiusMeters ?? this.defaultRadiusMeters,
      autoCreatePlaces: autoCreatePlaces ?? this.autoCreatePlaces,
      autoPlaceGroupId: clearAutoPlaceGroupId
          ? null
          : (autoPlaceGroupId ?? this.autoPlaceGroupId),
      autoPlacePlaceTypeIndex:
          autoPlacePlaceTypeIndex ?? this.autoPlacePlaceTypeIndex,
    );
  }
}
