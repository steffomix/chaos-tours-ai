import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A photo associated with a [SavedPlace] and/or a [Stay].
///
/// [photoData] is the full image stored as base64 so that it is included in
/// the standard timestamp-based sync without any extra file-transfer mechanism.
class PlacePhoto {
  final String uuid;

  /// UUID of the [SavedPlace] this photo belongs to (may be null for stay-only).
  final String? placeUuid;

  /// UUID of the [Stay] this photo belongs to (may be null for place-level).
  final String? stayUuid;

  final String caption;

  /// When the photo was taken (ms since epoch).
  final int takenAt;

  /// Base64-encoded JPEG/PNG image data.
  final String photoData;

  final int createdAt;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  PlacePhoto({
    String? uuid,
    this.placeUuid,
    this.stayUuid,
    this.caption = '',
    int? takenAt,
    required this.photoData,
    int? createdAt,
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       takenAt = takenAt ?? DateTime.now().millisecondsSinceEpoch,
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory PlacePhoto.fromMap(Map<String, dynamic> map) {
    return PlacePhoto(
      uuid: map['uuid'] as String?,
      placeUuid: map['place_uuid'] as String?,
      stayUuid: map['stay_uuid'] as String?,
      caption: (map['caption'] as String?) ?? '',
      takenAt:
          (map['taken_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      photoData: (map['photo_data'] as String?) ?? '',
      createdAt:
          (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
      deviceId: (map['device_id'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      if (placeUuid != null) 'place_uuid': placeUuid,
      if (stayUuid != null) 'stay_uuid': stayUuid,
      'caption': caption,
      'taken_at': takenAt,
      'photo_data': photoData,
      'created_at': createdAt,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  PlacePhoto copyWith({
    String? caption,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return PlacePhoto(
      uuid: uuid,
      placeUuid: placeUuid,
      stayUuid: stayUuid,
      caption: caption ?? this.caption,
      takenAt: takenAt,
      photoData: photoData,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId,
    );
  }
}
