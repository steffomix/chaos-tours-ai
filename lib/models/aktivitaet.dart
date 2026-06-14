import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A named settings profile. At most one is "active" at a time;
/// its settings are used by the tracking engine and are also
/// shown/edited in the Settings screen.
class Aktivitaet {
  final String uuid;
  final String name;
  final int gpsIntervalSeconds;
  final int stayDetectionSeconds;
  final int autoPlaceSeconds;
  final double defaultRadiusMeters;
  final bool autoCreatePlaces;

  /// UUID of the [PlaceGroup] for automatically created places, or null.
  final String? autoPlaceGroupUuid;

  /// UUID of the [PlaceGroup] pre-selected when the user creates a place manually.
  final String? defaultPlaceGroupUuid;

  /// How many days of stay history are shown on the timeline map (default: 7).
  final int timelineHistoryDays;

  /// Default country pre-filled in the map address search (e.g. 'Deutschland').
  final String searchCountry;

  /// Color-range in days for the scheduler urgency indicator (default: 14).
  /// >= colorRange = green, 0 = yellow, <= -colorRange = red.
  final int schedulerColorRange;

  /// Comma-separated group UUIDs to show in the map and scheduler.
  /// Empty string means "all groups".
  final String schedulerGroupIds;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  Aktivitaet({
    String? uuid,
    required this.name,
    this.gpsIntervalSeconds = 15,
    this.stayDetectionSeconds = 180,
    this.autoPlaceSeconds = 900,
    this.defaultRadiusMeters = 50.0,
    this.autoCreatePlaces = true,
    this.autoPlaceGroupUuid,
    this.defaultPlaceGroupUuid,
    this.timelineHistoryDays = 7,
    this.searchCountry = '',
    this.schedulerColorRange = 14,
    this.schedulerGroupIds = '',
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory Aktivitaet.fromMap(Map<String, dynamic> map) {
    return Aktivitaet(
      uuid: map['uuid'] as String?,
      name: map['name'] as String,
      gpsIntervalSeconds: map['gps_interval_seconds'] as int? ?? 15,
      stayDetectionSeconds: map['stay_detection_seconds'] as int? ?? 180,
      autoPlaceSeconds: map['auto_place_seconds'] as int? ?? 900,
      defaultRadiusMeters:
          (map['default_radius_meters'] as num?)?.toDouble() ?? 50.0,
      autoCreatePlaces: (map['auto_create_places'] as int? ?? 1) == 1,
      autoPlaceGroupUuid: map['auto_place_group_uuid'] as String?,
      defaultPlaceGroupUuid: map['default_place_group_uuid'] as String?,
      timelineHistoryDays: map['timeline_history_days'] as int? ?? 7,
      searchCountry: map['search_country'] as String? ?? '',
      schedulerColorRange: map['scheduler_color_range'] as int? ?? 14,
      schedulerGroupIds: map['scheduler_group_ids'] as String? ?? '',
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
      deviceId: (map['device_id'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'name': name,
      'gps_interval_seconds': gpsIntervalSeconds,
      'stay_detection_seconds': stayDetectionSeconds,
      'auto_place_seconds': autoPlaceSeconds,
      'default_radius_meters': defaultRadiusMeters,
      'auto_create_places': autoCreatePlaces ? 1 : 0,
      if (autoPlaceGroupUuid != null)
        'auto_place_group_uuid': autoPlaceGroupUuid,
      if (defaultPlaceGroupUuid != null)
        'default_place_group_uuid': defaultPlaceGroupUuid,
      'timeline_history_days': timelineHistoryDays,
      'search_country': searchCountry,
      'scheduler_color_range': schedulerColorRange,
      'scheduler_group_ids': schedulerGroupIds,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  Aktivitaet copyWith({
    String? uuid,
    String? name,
    int? gpsIntervalSeconds,
    int? stayDetectionSeconds,
    int? autoPlaceSeconds,
    double? defaultRadiusMeters,
    bool? autoCreatePlaces,
    String? autoPlaceGroupUuid,
    bool clearAutoPlaceGroupUuid = false,
    String? defaultPlaceGroupUuid,
    bool clearDefaultPlaceGroupUuid = false,
    int? timelineHistoryDays,
    String? searchCountry,
    int? schedulerColorRange,
    String? schedulerGroupIds,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return Aktivitaet(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      gpsIntervalSeconds: gpsIntervalSeconds ?? this.gpsIntervalSeconds,
      stayDetectionSeconds: stayDetectionSeconds ?? this.stayDetectionSeconds,
      autoPlaceSeconds: autoPlaceSeconds ?? this.autoPlaceSeconds,
      defaultRadiusMeters: defaultRadiusMeters ?? this.defaultRadiusMeters,
      autoCreatePlaces: autoCreatePlaces ?? this.autoCreatePlaces,
      autoPlaceGroupUuid: clearAutoPlaceGroupUuid
          ? null
          : (autoPlaceGroupUuid ?? this.autoPlaceGroupUuid),
      defaultPlaceGroupUuid: clearDefaultPlaceGroupUuid
          ? null
          : (defaultPlaceGroupUuid ?? this.defaultPlaceGroupUuid),
      timelineHistoryDays: timelineHistoryDays ?? this.timelineHistoryDays,
      searchCountry: searchCountry ?? this.searchCountry,
      schedulerColorRange: schedulerColorRange ?? this.schedulerColorRange,
      schedulerGroupIds: schedulerGroupIds ?? this.schedulerGroupIds,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
