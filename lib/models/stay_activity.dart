import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

class StayActivity {
  final String uuid;
  final String stayUuid;
  final String? activityUuid;
  final String description;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  StayActivity({
    String? uuid,
    required this.stayUuid,
    this.activityUuid,
    required this.description,
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  factory StayActivity.fromMap(Map<String, dynamic> map) {
    return StayActivity(
      uuid: map['uuid'] as String?,
      stayUuid: map['stay_uuid'] as String,
      activityUuid: map['activity_uuid'] as String?,
      description: map['description'] as String,
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
      if (activityUuid != null) 'activity_uuid': activityUuid,
      'description': description,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }
}
