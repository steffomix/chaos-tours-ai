import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

/// A user experience / note linked to a [SyncSource] by its UUID.
/// Multiple experiences can exist per sync source, from different devices.
class SyncSourceExperience {
  /// UUID of the parent [SyncSource].
  final String syncSourceUuid;

  /// The experience text written by the user.
  final String text;

  /// When this entry was created (ms since epoch).
  final int createdAt;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final String uuid;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  SyncSourceExperience({
    String? uuid,
    required this.syncSourceUuid,
    required this.text,
    int? createdAt,
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  factory SyncSourceExperience.fromMap(Map<String, dynamic> map) {
    return SyncSourceExperience(
      uuid: map['uuid'] as String?,
      syncSourceUuid: (map['sync_source_uuid'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      createdAt:
          (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
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
      'sync_source_uuid': syncSourceUuid,
      'text': text,
      'created_at': createdAt,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  SyncSourceExperience copyWith({
    String? uuid,
    String? syncSourceUuid,
    String? text,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return SyncSourceExperience(
      uuid: uuid ?? this.uuid,
      syncSourceUuid: syncSourceUuid ?? this.syncSourceUuid,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
