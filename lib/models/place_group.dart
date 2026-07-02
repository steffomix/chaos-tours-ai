import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';
import 'saved_place.dart';

const _uuid = Uuid();

class PlaceGroup {
  final String uuid;
  final String name;
  final String? telegramConnectionUuid;
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
    this.telegramConnectionUuid,
    this.includeNotes = true,
    this.includePersons = true,
    this.includeActivities = true,
    this.isAutoGroup = false,
    this.placeType = PlaceType.public,
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  factory PlaceGroup.fromMap(Map<String, dynamic> map) {
    final typeIndex = (map['place_type'] as int?) ?? 0;
    return PlaceGroup(
      uuid: map['uuid'] as String?,
      name: map['name'] as String,
      telegramConnectionUuid: map['telegram_connection_uuid'] as String?,
      includeNotes: (map['include_notes'] as int? ?? 1) == 1,
      includePersons: (map['include_persons'] as int? ?? 1) == 1,
      includeActivities: (map['include_activities'] as int? ?? 1) == 1,
      isAutoGroup: (map['is_auto_group'] as int? ?? 0) == 1,
      placeType:
          PlaceType.values[typeIndex.clamp(0, PlaceType.values.length - 1)],
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
      deviceId:
          (map['device_id'] as String?) ?? SettingsService.instance.deviceId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'name': name,
      if (telegramConnectionUuid != null)
        'telegram_connection_uuid': telegramConnectionUuid,
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
    String? telegramConnectionUuid,
    bool? includeNotes,
    bool? includePersons,
    bool? includeActivities,
    bool? isAutoGroup,
    PlaceType? placeType,
    bool clearTelegramConnectionUuid = false,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return PlaceGroup(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      telegramConnectionUuid: clearTelegramConnectionUuid
          ? null
          : (telegramConnectionUuid ?? this.telegramConnectionUuid),
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
