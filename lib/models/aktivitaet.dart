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

  /// Group ID pre-selected when the user creates a place manually.
  final int? defaultPlaceGroupId;

  /// How many days of stay history are shown on the timeline map (default: 7).
  final int timelineHistoryDays;

  /// Default country pre-filled in the map address search (e.g. 'Deutschland').
  final String searchCountry;

  /// Color-range in days for the scheduler urgency indicator (default: 14).
  /// >= colorRange = green, 0 = yellow, <= -colorRange = red.
  final int schedulerColorRange;

  /// Comma-separated group IDs to show in the map and scheduler.
  /// Empty string means "all groups".
  final String schedulerGroupIds;

  const Aktivitaet({
    this.id,
    required this.name,
    this.gpsIntervalSeconds = 15,
    this.stayDetectionSeconds = 180,
    this.autoPlaceSeconds = 900,
    this.defaultRadiusMeters = 50.0,
    this.autoCreatePlaces = true,
    this.autoPlaceGroupId,
    this.defaultPlaceGroupId,
    this.timelineHistoryDays = 7,
    this.searchCountry = '',
    this.schedulerColorRange = 14,
    this.schedulerGroupIds = '',
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
      defaultPlaceGroupId: map['default_place_group_id'] as int?,
      timelineHistoryDays: map['timeline_history_days'] as int? ?? 7,
      searchCountry: map['search_country'] as String? ?? '',
      schedulerColorRange: map['scheduler_color_range'] as int? ?? 14,
      schedulerGroupIds: map['scheduler_group_ids'] as String? ?? '',
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
      if (defaultPlaceGroupId != null)
        'default_place_group_id': defaultPlaceGroupId,
      'timeline_history_days': timelineHistoryDays,
      'search_country': searchCountry,
      'scheduler_color_range': schedulerColorRange,
      'scheduler_group_ids': schedulerGroupIds,
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
    int? defaultPlaceGroupId,
    bool clearDefaultPlaceGroupId = false,
    int? timelineHistoryDays,
    String? searchCountry,
    int? schedulerColorRange,
    String? schedulerGroupIds,
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
      defaultPlaceGroupId: clearDefaultPlaceGroupId
          ? null
          : (defaultPlaceGroupId ?? this.defaultPlaceGroupId),
      timelineHistoryDays: timelineHistoryDays ?? this.timelineHistoryDays,
      searchCountry: searchCountry ?? this.searchCountry,
      schedulerColorRange: schedulerColorRange ?? this.schedulerColorRange,
      schedulerGroupIds: schedulerGroupIds ?? this.schedulerGroupIds,
    );
  }
}
