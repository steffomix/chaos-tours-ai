import 'package:uuid/uuid.dart';

import 'saved_place.dart';

const _uuid = Uuid();

class PlaceGroup {
  final String uuid;
  final String name;
  final String? calendarId;
  final bool includeNotes;
  final bool includePersons;
  final bool includeActivities;
  final bool isAutoGroup;
  final PlaceType placeType;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  PlaceGroup({
    String? uuid,
    required this.name,
    this.calendarId,
    this.includeNotes = true,
    this.includePersons = true,
    this.includeActivities = true,
    this.isAutoGroup = false,
    this.placeType = PlaceType.public,
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory PlaceGroup.fromMap(Map<String, dynamic> map) {
    final typeIndex = (map['place_type'] as int?) ?? 0;
    return PlaceGroup(
      uuid: map['uuid'] as String?,
      name: map['name'] as String,
      calendarId: map['calendar_id'] as String?,
      includeNotes: (map['include_notes'] as int? ?? 1) == 1,
      includePersons: (map['include_persons'] as int? ?? 1) == 1,
      includeActivities: (map['include_activities'] as int? ?? 1) == 1,
      isAutoGroup: (map['is_auto_group'] as int? ?? 0) == 1,
      placeType:
          PlaceType.values[typeIndex.clamp(0, PlaceType.values.length - 1)],
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
      if (calendarId != null) 'calendar_id': calendarId,
      'include_notes': includeNotes ? 1 : 0,
      'include_persons': includePersons ? 1 : 0,
      'include_activities': includeActivities ? 1 : 0,
      'is_auto_group': isAutoGroup ? 1 : 0,
      'place_type': placeType.index,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  PlaceGroup copyWith({
    String? uuid,
    String? name,
    String? calendarId,
    bool? includeNotes,
    bool? includePersons,
    bool? includeActivities,
    bool? isAutoGroup,
    PlaceType? placeType,
    bool clearCalendarId = false,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return PlaceGroup(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      calendarId: clearCalendarId ? null : (calendarId ?? this.calendarId),
      includeNotes: includeNotes ?? this.includeNotes,
      includePersons: includePersons ?? this.includePersons,
      includeActivities: includeActivities ?? this.includeActivities,
      isAutoGroup: isAutoGroup ?? this.isAutoGroup,
      placeType: placeType ?? this.placeType,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
