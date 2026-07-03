import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

/// Links a [Message] to a photo stored in the `place_photos` table.
///
/// Attachments reference existing [place_photos] rows by [photoUuid] rather
/// than embedding image bytes, so a single photo can be shared by place, stay
/// and message contexts. Referenced photos are always synced along with the
/// message so they remain available at other mesh nodes.
class MessageAttachment {
  final String uuid;

  /// Author identity — device ID of the creator.
  final String deviceId;

  /// UUID of the owning [Message].
  final String messageUuid;

  /// UUID of the referenced `place_photos` row.
  final String photoUuid;

  final int createdAt;

  // ── Sync fields ────────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;

  MessageAttachment({
    String? uuid,
    String? deviceId,
    required this.messageUuid,
    required this.photoUuid,
    int? createdAt,
    int? updatedAt,
    this.deletedAt,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId,
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory MessageAttachment.fromMap(Map<String, dynamic> map) {
    return MessageAttachment(
      uuid: map['uuid'] as String?,
      deviceId: map['device_id'] as String?,
      messageUuid: map['message_uuid'] as String,
      photoUuid: map['photo_uuid'] as String,
      createdAt:
          (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'device_id': deviceId,
      'message_uuid': messageUuid,
      'photo_uuid': photoUuid,
      'created_at': createdAt,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    };
  }

  MessageAttachment copyWith({
    String? uuid,
    String? deviceId,
    String? messageUuid,
    String? photoUuid,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return MessageAttachment(
      uuid: uuid ?? this.uuid,
      deviceId: deviceId ?? this.deviceId,
      messageUuid: messageUuid ?? this.messageUuid,
      photoUuid: photoUuid ?? this.photoUuid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
