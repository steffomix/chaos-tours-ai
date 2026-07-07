import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';
import 'sync_source.dart';

const _uuid = Uuid();

/// Type of a saved place — determines behaviour and map appearance.
enum PlaceType {
  /// Green dot. Notification on arrival, Nominatim lookup, DB stay, Calendar event.
  public,

  /// Blue dot. Notification on arrival, Nominatim lookup, DB stay. No calendar.
  private,

  /// Red dot. Shown on map only — no notification, no stay tracking.
  secret,

  /// Only visible in the places list when "Verbotene Orte auflisten" is enabled.
  forbidden,

  /// Orange dot. Automatically created at a P2P sync opportunity (mesh node /
  /// peer). Anchors location-bound messages. No notification, no stay tracking,
  /// no calendar sync.
  syncSource,
}

extension PlaceTypeExtension on PlaceType {
  String get label {
    switch (this) {
      case PlaceType.public:
        return 'Öffentlich';
      case PlaceType.private:
        return 'Privat';
      case PlaceType.secret:
        return 'Geheim';
      case PlaceType.forbidden:
        return 'Verboten';
      case PlaceType.syncSource:
        return 'Sync-Quelle';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaceType.public:
        return Icons.public;
      case PlaceType.private:
        return Icons.lock;
      case PlaceType.secret:
        return Icons.visibility_off;
      case PlaceType.forbidden:
        return Icons.block;
      case PlaceType.syncSource:
        return Icons.hub;
    }
  }

  Color get dotColor {
    switch (this) {
      case PlaceType.public:
        return Colors.green;
      case PlaceType.private:
        return Colors.blue;
      case PlaceType.secret:
        return Colors.red;
      case PlaceType.forbidden:
        return Colors.grey;
      case PlaceType.syncSource:
        return Colors.orange;
    }
  }

  Color get fillColor => dotColor.withValues(alpha: 0.45);

  /// Whether arrival at this place triggers stay tracking.
  bool get tracksStay => this == PlaceType.public || this == PlaceType.private;

  /// Whether arrival triggers a system notification.
  bool get notifiesOnArrival =>
      this == PlaceType.public || this == PlaceType.private;

  /// Whether a completed stay is written to the calendar or telegram.
  bool get syncEnabled => this == PlaceType.public;
}

/// How a SavedPlace was created / obtained.
enum PlaceOriginType {
  /// 0 — created by the user on this device.
  self,

  /// 1 — automatically detected by the tracking engine.
  auto,

  /// 2 — imported from an external source (web_sources entry).
  imported,
}

class SavedPlace {
  final String uuid;
  final String name;
  final double lat;
  final double lng;
  final double radius;
  final PlaceType placeType;
  final String notes;

  /// UUID of the linked [PlaceGroup], or null.
  final String? groupUuid;

  /// Creation timestamp (milliseconds since epoch).
  final int createdAt;

  /// Whether the visit interval scheduler is enabled for this place.
  final bool intervalEnabled;

  /// Target interval in days between visits (null = not configured).
  final int? intervalDays;

  // ── Sync fields ──────────────────────────────────────────────────────────

  // ── Sync fields ──────────────────────────────────────────────────────────

  /// Last modification timestamp in ms since epoch.
  final int updatedAt;

  /// Soft-delete timestamp (null = record is active).
  final int? deletedAt;

  /// ID of the device that created this record.
  final String deviceId;

  // ── Origin fields ────────────────────────────────────────────────────────

  /// How this place was created.
  final PlaceOriginType originType;

  /// UUID of the [SyncSource] this place was imported from, or null.
  final String? originSourceUuid;

  /// Optional website URL for this place.
  final String website;

  /// Optional contact email for this place.
  final String email;

  /// Optional contact phone number for this place.
  final String phone;

  /// Cached average of all experience ratings across 6 dimensions.
  /// Null when no experiences exist.
  final double? experienceRatingAverage;

  /// Cached median of all experience ratings across 6 dimensions.
  /// Null when no experiences exist.
  final double? experienceRatingMedian;

  // ── P2P Sync fields ─────────────────────────────────────────────────────

  /// P2P sync server URL without port (e.g. http://192.168.4.1).
  final String syncUrl;

  /// P2P sync server port (default: 8000).
  final int syncPort;

  /// API key for authenticating against the P2P sync server.
  final String syncApiKey;

  /// Free-text notes about this sync configuration.
  final String syncNotes;

  /// Per-table sync options. Defaults to [SyncSourceOptions.p2pDefault].
  final SyncSourceOptions syncOptions;

  /// Automatic sync interval in minutes. 0 = auto-sync disabled. Range: 10–600 (steps of 10).
  final int syncIntervalMinutes;

  /// Timestamp of the last successful P2P sync (ms since epoch, 0 = never).
  final int syncLastMs;

  SavedPlace({
    String? uuid,
    required this.name,
    required this.lat,
    required this.lng,
    this.radius = 50.0,
    this.placeType = PlaceType.private,
    this.notes = '',
    this.groupUuid,
    int? createdAt,
    this.intervalEnabled = false,
    this.intervalDays,
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
    this.originType = PlaceOriginType.self,
    this.originSourceUuid,
    this.website = '',
    this.email = '',
    this.phone = '',
    this.experienceRatingAverage,
    this.experienceRatingMedian,
    this.syncUrl = '',
    this.syncPort = 8000,
    this.syncApiKey = '',
    this.syncNotes = '',
    SyncSourceOptions? syncOptions,
    this.syncIntervalMinutes = 0,
    int? syncLastMs,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       syncOptions = syncOptions ?? SyncSourceOptions.p2pDefault(),
       syncLastMs = syncLastMs ?? 0,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  factory SavedPlace.fromMap(Map<String, dynamic> map) {
    final typeIndex = (map['place_type'] as int?) ?? 0;
    final originIndex = (map['origin_type'] as int?) ?? 0;
    return SavedPlace(
      uuid: map['uuid'] as String?,
      name: map['name'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      radius: (map['radius'] as num?)?.toDouble() ?? 50.0,
      placeType:
          PlaceType.values[typeIndex.clamp(0, PlaceType.values.length - 1)],
      notes: (map['notes'] as String?) ?? '',
      groupUuid: map['group_uuid'] as String?,
      createdAt:
          (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      intervalEnabled: (map['interval_enabled'] as int? ?? 0) == 1,
      intervalDays: map['interval_days'] as int?,
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
      deviceId:
          (map['device_id'] as String?) ?? SettingsService.instance.deviceId,
      originType: PlaceOriginType
          .values[originIndex.clamp(0, PlaceOriginType.values.length - 1)],
      originSourceUuid: map['origin_source_uuid'] as String?,
      website: (map['website'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      experienceRatingAverage: (map['experience_rating_average'] as num?)
          ?.toDouble(),
      experienceRatingMedian: (map['experience_rating_median'] as num?)
          ?.toDouble(),
      syncUrl: (map['sync_url'] as String?) ?? '',
      syncPort: (map['sync_port'] as int?) ?? 8000,
      syncApiKey: (map['sync_api_key'] as String?) ?? '',
      syncNotes: (map['sync_notes'] as String?) ?? '',
      syncOptions: _parseSyncOptions(map['sync_options'] as String?),
      syncIntervalMinutes: (map['sync_intervall'] as int?) ?? 0,
      syncLastMs: (map['sync_last_ms'] as int?) ?? 0,
    );
  }

  static SyncSourceOptions _parseSyncOptions(String? raw) {
    if (raw == null || raw.isEmpty || raw == '{}') {
      return SyncSourceOptions.p2pDefault();
    }
    return SyncSourceOptions.fromJson(raw);
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'notes': notes,
      'created_at': createdAt,
      if (groupUuid != null) 'group_uuid': groupUuid,
      'interval_enabled': intervalEnabled ? 1 : 0,
      if (intervalDays != null) 'interval_days': intervalDays,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
      'origin_type': originType.index,
      if (originSourceUuid != null) 'origin_source_uuid': originSourceUuid,
      'website': website,
      'email': email,
      'phone': phone,
      'sync_url': syncUrl,
      'sync_port': syncPort,
      'sync_api_key': syncApiKey,
      'sync_notes': syncNotes,
      'sync_options': syncOptions.toJson(),
      'sync_intervall': syncIntervalMinutes,
      'sync_last_ms': syncLastMs,
    };
  }

  SavedPlace copyWith({
    String? uuid,
    String? name,
    double? lat,
    double? lng,
    double? radius,
    PlaceType? placeType,
    String? notes,
    String? groupUuid,
    int? createdAt,
    bool clearGroupUuid = false,
    bool? intervalEnabled,
    int? intervalDays,
    bool clearIntervalDays = false,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
    PlaceOriginType? originType,
    String? originSourceUuid,
    bool clearOriginSourceUuid = false,
    String? website,
    String? email,
    String? phone,
    double? experienceRatingAverage,
    double? experienceRatingMedian,
    String? syncUrl,
    int? syncPort,
    String? syncApiKey,
    String? syncNotes,
    SyncSourceOptions? syncOptions,
    int? syncIntervalMinutes,
    int? syncLastMs,
  }) {
    return SavedPlace(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radius: radius ?? this.radius,
      placeType: placeType ?? this.placeType,
      notes: notes ?? this.notes,
      groupUuid: clearGroupUuid ? null : (groupUuid ?? this.groupUuid),
      createdAt: createdAt ?? this.createdAt,
      intervalEnabled: intervalEnabled ?? this.intervalEnabled,
      intervalDays: clearIntervalDays
          ? null
          : (intervalDays ?? this.intervalDays),
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
      originType: originType ?? this.originType,
      originSourceUuid: clearOriginSourceUuid
          ? null
          : (originSourceUuid ?? this.originSourceUuid),
      website: website ?? this.website,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      experienceRatingAverage:
          experienceRatingAverage ?? this.experienceRatingAverage,
      experienceRatingMedian:
          experienceRatingMedian ?? this.experienceRatingMedian,
      syncUrl: syncUrl ?? this.syncUrl,
      syncPort: syncPort ?? this.syncPort,
      syncApiKey: syncApiKey ?? this.syncApiKey,
      syncNotes: syncNotes ?? this.syncNotes,
      syncOptions: syncOptions ?? this.syncOptions,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      syncLastMs: syncLastMs ?? this.syncLastMs,
    );
  }
}
