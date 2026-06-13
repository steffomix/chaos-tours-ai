import 'package:flutter/material.dart';

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
    }
  }

  Color get fillColor => dotColor.withValues(alpha: 0.45);

  /// Whether arrival at this place triggers stay tracking.
  bool get tracksStay => this == PlaceType.public || this == PlaceType.private;

  /// Whether arrival triggers a system notification.
  bool get notifiesOnArrival =>
      this == PlaceType.public || this == PlaceType.private;

  /// Whether a completed stay is written to the calendar.
  bool get syncsCalendar => this == PlaceType.public;
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
  final int? id;
  final String name;
  final double lat;
  final double lng;
  final double radius;
  final PlaceType placeType;
  final String notes;
  final int? groupId;

  /// Creation timestamp (milliseconds since epoch).
  final int createdAt;

  /// Whether the visit interval scheduler is enabled for this place.
  final bool intervalEnabled;

  /// Target interval in days between visits (null = not configured).
  final int? intervalDays;

  // ── Sync fields ──────────────────────────────────────────────────────────

  /// Globally unique identifier (UUID v4). Set once on creation.
  final String uuid;

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

  SavedPlace({
    this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.radius = 50.0,
    this.placeType = PlaceType.private,
    this.notes = '',
    this.groupId,
    int? createdAt,
    this.intervalEnabled = false,
    this.intervalDays,
    String? uuid,
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
    this.originType = PlaceOriginType.self,
    this.originSourceUuid,
    this.website = '',
    this.email = '',
    this.phone = '',
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       uuid = uuid ?? '',
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory SavedPlace.fromMap(Map<String, dynamic> map) {
    final typeIndex = (map['place_type'] as int?) ?? 0;
    final originIndex = (map['origin_type'] as int?) ?? 0;
    return SavedPlace(
      id: map['id'] as int?,
      name: map['name'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      radius: (map['radius'] as num?)?.toDouble() ?? 50.0,
      placeType:
          PlaceType.values[typeIndex.clamp(0, PlaceType.values.length - 1)],
      notes: (map['notes'] as String?) ?? '',
      groupId: map['group_id'] as int?,
      createdAt:
          (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      intervalEnabled: (map['interval_enabled'] as int? ?? 0) == 1,
      intervalDays: map['interval_days'] as int?,
      uuid: (map['uuid'] as String?) ?? '',
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
      deviceId: (map['device_id'] as String?) ?? '',
      originType: PlaceOriginType
          .values[originIndex.clamp(0, PlaceOriginType.values.length - 1)],
      originSourceUuid: map['origin_source_uuid'] as String?,
      website: (map['website'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'notes': notes,
      'created_at': createdAt,
      if (groupId != null) 'group_id': groupId,
      'interval_enabled': intervalEnabled ? 1 : 0,
      if (intervalDays != null) 'interval_days': intervalDays,
      'uuid': uuid,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
      'origin_type': originType.index,
      if (originSourceUuid != null) 'origin_source_uuid': originSourceUuid,
      'website': website,
      'email': email,
      'phone': phone,
    };
  }

  SavedPlace copyWith({
    int? id,
    String? name,
    double? lat,
    double? lng,
    double? radius,
    PlaceType? placeType,
    String? notes,
    int? groupId,
    int? createdAt,
    bool clearGroupId = false,
    bool? intervalEnabled,
    int? intervalDays,
    bool clearIntervalDays = false,
    String? uuid,
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
  }) {
    return SavedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radius: radius ?? this.radius,
      placeType: placeType ?? this.placeType,
      notes: notes ?? this.notes,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      createdAt: createdAt ?? this.createdAt,
      intervalEnabled: intervalEnabled ?? this.intervalEnabled,
      intervalDays: clearIntervalDays
          ? null
          : (intervalDays ?? this.intervalDays),
      uuid: uuid ?? this.uuid,
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
    );
  }
}
