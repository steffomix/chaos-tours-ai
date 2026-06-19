import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

class StayPerson {
  final String uuid;
  final String stayUuid;
  final String? personUuid;
  final String name;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  StayPerson({
    String? uuid,
    required this.stayUuid,
    this.personUuid,
    required this.name,
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  factory StayPerson.fromMap(Map<String, dynamic> map) {
    return StayPerson(
      uuid: map['uuid'] as String?,
      stayUuid: map['stay_uuid'] as String,
      personUuid: map['person_uuid'] as String?,
      name: map['name'] as String,
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
      'stay_uuid': stayUuid,
      if (personUuid != null) 'person_uuid': personUuid,
      'name': name,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }
}
