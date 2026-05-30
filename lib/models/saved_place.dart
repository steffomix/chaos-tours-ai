import 'package:flutter/material.dart';

/// Color type index: 0=Red, 1=Green, 2=Blue, 3=Yellow
enum PlaceColorType { red, green, blue, yellow }

extension PlaceColorTypeExtension on PlaceColorType {
  Color get color {
    switch (this) {
      case PlaceColorType.red:
        return Colors.red.withValues(alpha: 0.5);
      case PlaceColorType.green:
        return Colors.green.withValues(alpha: 0.5);
      case PlaceColorType.blue:
        return Colors.blue.withValues(alpha: 0.5);
      case PlaceColorType.yellow:
        return Colors.yellow.withValues(alpha: 0.5);
    }
  }

  Color get borderColor {
    switch (this) {
      case PlaceColorType.red:
        return Colors.red;
      case PlaceColorType.green:
        return Colors.green;
      case PlaceColorType.blue:
        return Colors.blue;
      case PlaceColorType.yellow:
        return Colors.yellow;
    }
  }
}

class SavedPlace {
  final int? id;
  final String name;
  final double lat;
  final double lng;
  final double radius;
  final int colorType;
  final String notes;
  final int? groupId;

  SavedPlace({
    this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.radius = 50.0,
    this.colorType = 0,
    this.notes = '',
    this.groupId,
  });

  PlaceColorType get placeColorType =>
      PlaceColorType.values[colorType.clamp(0, 3)];

  factory SavedPlace.fromMap(Map<String, dynamic> map) {
    return SavedPlace(
      id: map['id'] as int?,
      name: map['name'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      radius: (map['radius'] as num?)?.toDouble() ?? 50.0,
      colorType: (map['color_type'] as int?) ?? 0,
      notes: (map['notes'] as String?) ?? '',
      groupId: map['group_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius': radius,
      'color_type': colorType,
      'notes': notes,
      if (groupId != null) 'group_id': groupId,
    };
  }

  SavedPlace copyWith({
    int? id,
    String? name,
    double? lat,
    double? lng,
    double? radius,
    int? colorType,
    String? notes,
    int? groupId,
    bool clearGroupId = false,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      radius: radius ?? this.radius,
      colorType: colorType ?? this.colorType,
      notes: notes ?? this.notes,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
    );
  }
}
