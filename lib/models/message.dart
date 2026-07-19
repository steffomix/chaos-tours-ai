import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

/// A location-bound P2P message anchored to a [SavedPlace].
///
/// Messages travel between devices and mesh nodes via store-and-forward sync.
/// The author is identified purely by [deviceId] — there is no login. Messages
/// may reference another message via [replyToUuid] to form forum-like threads.
class Message {
  final String uuid;

  /// Author identity — the device ID of the sender.
  final String deviceId;

  /// UUID of the [SavedPlace] this message is anchored to. Always set —
  /// location-bound messaging requires a place.
  final String placeUuid;

  /// UUID of the message this one replies to, or null for a root message.
  final String? replyToUuid;

  /// The message text.
  final String body;

  /// Optional photo embedded directly in this message (empty if none).
  final Uint8List photoData;

  /// Creation timestamp (milliseconds since epoch).
  final int createdAt;

  // ── Sync fields ────────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;

  Message({
    String? uuid,
    String? deviceId,
    required this.placeUuid,
    this.replyToUuid,
    this.body = '',
    Uint8List? photoData,
    int? createdAt,
    int? updatedAt,
    this.deletedAt,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId,
       photoData = photoData ?? Uint8List(0),
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      uuid: map['uuid'] as String?,
      deviceId: map['device_id'] as String?,
      placeUuid: map['place_uuid'] as String,
      replyToUuid: map['reply_to_uuid'] as String?,
      body: (map['body'] as String?) ?? '',
      photoData: (map['photo_data'] as Uint8List?) ?? Uint8List(0),
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
      'place_uuid': placeUuid,
      if (replyToUuid != null) 'reply_to_uuid': replyToUuid,
      'body': body,
      'photo_data': photoData,
      'created_at': createdAt,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    };
  }

  Message copyWith({
    String? uuid,
    String? deviceId,
    String? placeUuid,
    String? replyToUuid,
    bool clearReplyToUuid = false,
    String? body,
    Uint8List? photoData,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Message(
      uuid: uuid ?? this.uuid,
      deviceId: deviceId ?? this.deviceId,
      placeUuid: placeUuid ?? this.placeUuid,
      replyToUuid: clearReplyToUuid ? null : (replyToUuid ?? this.replyToUuid),
      body: body ?? this.body,
      photoData: photoData ?? this.photoData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
