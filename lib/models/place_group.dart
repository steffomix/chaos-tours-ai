import 'saved_place.dart';

class PlaceGroup {
  final int? id;
  final String name;
  final String? calendarId;
  final bool includeNotes;
  final bool includePersons;
  final bool includeActivities;
  final bool isAutoGroup;
  final PlaceType placeType;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final String uuid;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  PlaceGroup({
    this.id,
    required this.name,
    this.calendarId,
    this.includeNotes = true,
    this.includePersons = true,
    this.includeActivities = true,
    this.isAutoGroup = false,
    this.placeType = PlaceType.public,
    String? uuid,
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
  }) : uuid = uuid ?? '',
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory PlaceGroup.fromMap(Map<String, dynamic> map) {
    final typeIndex = (map['place_type'] as int?) ?? 0;
    return PlaceGroup(
      id: map['id'] as int?,
      name: map['name'] as String,
      calendarId: map['calendar_id'] as String?,
      includeNotes: (map['include_notes'] as int? ?? 1) == 1,
      includePersons: (map['include_persons'] as int? ?? 1) == 1,
      includeActivities: (map['include_activities'] as int? ?? 1) == 1,
      isAutoGroup: (map['is_auto_group'] as int? ?? 0) == 1,
      placeType:
          PlaceType.values[typeIndex.clamp(0, PlaceType.values.length - 1)],
      uuid: (map['uuid'] as String?) ?? '',
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
      deviceId: (map['device_id'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (calendarId != null) 'calendar_id': calendarId,
      'include_notes': includeNotes ? 1 : 0,
      'include_persons': includePersons ? 1 : 0,
      'include_activities': includeActivities ? 1 : 0,
      'is_auto_group': isAutoGroup ? 1 : 0,
      'place_type': placeType.index,
      'uuid': uuid,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  PlaceGroup copyWith({
    int? id,
    String? name,
    String? calendarId,
    bool? includeNotes,
    bool? includePersons,
    bool? includeActivities,
    bool? isAutoGroup,
    PlaceType? placeType,
    bool clearCalendarId = false,
    String? uuid,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return PlaceGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      calendarId: clearCalendarId ? null : (calendarId ?? this.calendarId),
      includeNotes: includeNotes ?? this.includeNotes,
      includePersons: includePersons ?? this.includePersons,
      includeActivities: includeActivities ?? this.includeActivities,
      isAutoGroup: isAutoGroup ?? this.isAutoGroup,
      placeType: placeType ?? this.placeType,
      uuid: uuid ?? this.uuid,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
