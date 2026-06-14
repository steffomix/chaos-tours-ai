import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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
    this.deviceId = '',
    this.originType = PlaceOriginType.self,
    this.originSourceUuid,
    this.website = '',
    this.email = '',
    this.phone = '',
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

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
    );
  }
}
