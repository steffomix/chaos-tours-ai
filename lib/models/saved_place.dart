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
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  factory SavedPlace.fromMap(Map<String, dynamic> map) {
    final typeIndex = (map['place_type'] as int?) ?? 0;
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
    );
  }
}
