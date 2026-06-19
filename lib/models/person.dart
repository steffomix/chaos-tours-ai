import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

class Person {
  final String uuid;
  final String name;
  final String role;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  Person({
    String? uuid,
    required this.name,
    this.role = '',
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      uuid: map['uuid'] as String?,
      name: map['name'] as String,
      role: (map['role'] as String?) ?? '',
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
      'role': role,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  Person copyWith({
    String? uuid,
    String? name,
    String? role,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return Person(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      role: role ?? this.role,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
