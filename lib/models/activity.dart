import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

class Activity {
  final String uuid;
  final String name;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  Activity({
    String? uuid,
    required this.name,
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      uuid: map['uuid'] as String?,
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
      'name': name,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  Activity copyWith({
    String? uuid,
    String? name,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return Activity(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
