import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

/// A missleading name, but this is actually a "virtual device" profile,
/// which contains all the settings for the entire application.
/// A named settings profile. At most one is "active" at a time;
/// its settings are used by the tracking engine and are also
/// shown/edited in the Settings screen.
class VirtualDevice {
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

  /// UUID of the [PlaceGroup] used for synchronization.
  final String? syncSourcePlaceGroupUuid;

  /// How many days of stay history are shown on the timeline map (default: 7).
  final int timelineHistoryDays;

  /// Default country pre-filled in the map address search (e.g. 'Deutschland').
  final String searchCountry;

  /// Whether to query the address (Nominatim) when a place is auto-created.
  final bool addressOnAutoCreate;

  /// Whether to pre-fill the address as name on manual place creation.
  final bool addressOnManualCreate;

  /// Whether to query the address on every GPS tracking interval.
  final bool addressOnInterval;

  /// Color-range in days for the scheduler urgency indicator (default: 14).
  /// >= colorRange = green, 0 = yellow, <= -colorRange = red.
  final int schedulerColorRange;

  // ── Experience / distance filter ─────────────────────────────────────────
  final bool filterRequireExperiences;
  final double filterMinAvgRating;
  final bool filterDistanceEnabled;
  final double filterMaxDistanceKm;
  final bool filterUseMedian;
  final bool filterUseSpecificRating;
  final String filterSpecificRatingField;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  // ── Privater Bereich / Sync-Schutz ───────────────────────────────────────
  /// When true, data rows with this device_id are excluded from sync exports.
  final bool syncExportProtected;

  /// When true, incoming sync rows with this device_id are ignored on import.
  final bool syncImportProtected;

  VirtualDevice({
    String? uuid,
    required this.name,
    this.gpsIntervalSeconds = 15,
    this.stayDetectionSeconds = 180,
    this.autoPlaceSeconds = 900,
    this.defaultRadiusMeters = 50.0,
    this.autoCreatePlaces = true,
    this.autoPlaceGroupUuid,
    this.defaultPlaceGroupUuid,
    this.syncSourcePlaceGroupUuid,
    this.timelineHistoryDays = 7,
    this.searchCountry = '',
    this.addressOnAutoCreate = true,
    this.addressOnManualCreate = true,
    this.addressOnInterval = false,
    this.schedulerColorRange = 14,
    this.filterRequireExperiences = false,
    this.filterMinAvgRating = 0.0,
    this.filterDistanceEnabled = false,
    this.filterMaxDistanceKm = 100.0,
    this.filterUseMedian = false,
    this.filterUseSpecificRating = false,
    this.filterSpecificRatingField = '',
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
    this.syncExportProtected = false,
    this.syncImportProtected = false,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  factory VirtualDevice.fromMap(Map<String, dynamic> map) {
    return VirtualDevice(
      uuid: map['uuid'] as String?,
      name: map['name'] as String,
      deviceId:
          (map['device_id'] as String?) ?? SettingsService.instance.deviceId,
      gpsIntervalSeconds: map['gps_interval_seconds'] as int? ?? 15,
      stayDetectionSeconds: map['stay_detection_seconds'] as int? ?? 180,
      autoPlaceSeconds: map['auto_place_seconds'] as int? ?? 900,
      defaultRadiusMeters:
          (map['default_radius_meters'] as num?)?.toDouble() ?? 50.0,
      autoCreatePlaces: (map['auto_create_places'] as int? ?? 1) == 1,
      autoPlaceGroupUuid: map['auto_place_group_uuid'] as String?,
      defaultPlaceGroupUuid: map['default_place_group_uuid'] as String?,
      syncSourcePlaceGroupUuid: map['sync_source_place_group_uuid'] as String?,
      timelineHistoryDays: map['timeline_history_days'] as int? ?? 7,
      searchCountry: map['search_country'] as String? ?? '',
      addressOnAutoCreate: (map['address_on_auto_create'] as int? ?? 1) == 1,
      addressOnManualCreate:
          (map['address_on_manual_create'] as int? ?? 1) == 1,
      addressOnInterval: (map['address_on_interval'] as int? ?? 0) == 1,
      schedulerColorRange: map['scheduler_color_range'] as int? ?? 14,
      filterRequireExperiences:
          (map['filter_require_experiences'] as int? ?? 0) == 1,
      filterMinAvgRating:
          (map['filter_min_avg_rating'] as num?)?.toDouble() ?? 0.0,
      filterDistanceEnabled: (map['filter_distance_enabled'] as int? ?? 0) == 1,
      filterMaxDistanceKm:
          (map['filter_max_distance_km'] as num?)?.toDouble() ?? 100.0,
      filterUseMedian: (map['filter_use_median'] as int? ?? 0) == 1,
      filterUseSpecificRating:
          (map['filter_use_specific_rating'] as int? ?? 0) == 1,
      filterSpecificRatingField:
          map['filter_specific_rating_field'] as String? ?? '',
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
      syncExportProtected: (map['sync_export_protected'] as int? ?? 0) == 1,
      syncImportProtected: (map['sync_import_protected'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'name': name,
      'device_id': deviceId,
      'gps_interval_seconds': gpsIntervalSeconds,
      'stay_detection_seconds': stayDetectionSeconds,
      'auto_place_seconds': autoPlaceSeconds,
      'default_radius_meters': defaultRadiusMeters,
      'auto_create_places': autoCreatePlaces ? 1 : 0,
      if (autoPlaceGroupUuid != null)
        'auto_place_group_uuid': autoPlaceGroupUuid,
      if (defaultPlaceGroupUuid != null)
        'default_place_group_uuid': defaultPlaceGroupUuid,
      if (syncSourcePlaceGroupUuid != null)
        'sync_source_place_group_uuid': syncSourcePlaceGroupUuid,
      'timeline_history_days': timelineHistoryDays,
      'search_country': searchCountry,
      'address_on_auto_create': addressOnAutoCreate ? 1 : 0,
      'address_on_manual_create': addressOnManualCreate ? 1 : 0,
      'address_on_interval': addressOnInterval ? 1 : 0,
      'scheduler_color_range': schedulerColorRange,
      'filter_require_experiences': filterRequireExperiences ? 1 : 0,
      'filter_min_avg_rating': filterMinAvgRating,
      'filter_distance_enabled': filterDistanceEnabled ? 1 : 0,
      'filter_max_distance_km': filterMaxDistanceKm,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'filter_use_median': filterUseMedian ? 1 : 0,
      'filter_use_specific_rating': filterUseSpecificRating ? 1 : 0,
      'filter_specific_rating_field': filterSpecificRatingField,
      'sync_export_protected': syncExportProtected ? 1 : 0,
      'sync_import_protected': syncImportProtected ? 1 : 0,
    };
  }

  VirtualDevice copyWith({
    String? uuid,
    String? name,
    String? deviceId,
    int? gpsIntervalSeconds,
    int? stayDetectionSeconds,
    int? autoPlaceSeconds,
    double? defaultRadiusMeters,
    bool? autoCreatePlaces,
    String? autoPlaceGroupUuid,
    bool clearAutoPlaceGroupUuid = false,
    String? defaultPlaceGroupUuid,
    bool clearDefaultPlaceGroupUuid = false,
    String? syncSourcePlaceGroupUuid,
    bool clearSyncSourcePlaceGroupUuid = false,
    int? timelineHistoryDays,
    String? searchCountry,
    bool? addressOnAutoCreate,
    bool? addressOnManualCreate,
    bool? addressOnInterval,
    int? schedulerColorRange,
    bool? filterRequireExperiences,
    double? filterMinAvgRating,
    bool? filterDistanceEnabled,
    double? filterMaxDistanceKm,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    bool? filterUseMedian,
    bool? filterUseSpecificRating,
    String? filterSpecificRatingField,
    bool? syncExportProtected,
    bool? syncImportProtected,
  }) {
    return VirtualDevice(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
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
      syncSourcePlaceGroupUuid: clearSyncSourcePlaceGroupUuid
          ? null
          : (syncSourcePlaceGroupUuid ?? this.syncSourcePlaceGroupUuid),
      timelineHistoryDays: timelineHistoryDays ?? this.timelineHistoryDays,
      searchCountry: searchCountry ?? this.searchCountry,
      addressOnAutoCreate: addressOnAutoCreate ?? this.addressOnAutoCreate,
      addressOnManualCreate:
          addressOnManualCreate ?? this.addressOnManualCreate,
      addressOnInterval: addressOnInterval ?? this.addressOnInterval,
      schedulerColorRange: schedulerColorRange ?? this.schedulerColorRange,
      filterRequireExperiences:
          filterRequireExperiences ?? this.filterRequireExperiences,
      filterMinAvgRating: filterMinAvgRating ?? this.filterMinAvgRating,
      filterDistanceEnabled:
          filterDistanceEnabled ?? this.filterDistanceEnabled,
      filterMaxDistanceKm: filterMaxDistanceKm ?? this.filterMaxDistanceKm,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      filterUseMedian: filterUseMedian ?? this.filterUseMedian,
      filterUseSpecificRating:
          filterUseSpecificRating ?? this.filterUseSpecificRating,
      filterSpecificRatingField:
          filterSpecificRatingField ?? this.filterSpecificRatingField,
      syncExportProtected: syncExportProtected ?? this.syncExportProtected,
      syncImportProtected: syncImportProtected ?? this.syncImportProtected,
    );
  }
}
