/// A user experience / review entry linked to a [WebSource] by its UUID.
/// Multiple experiences can exist per web source, from different devices.
class WebSourceExperience {
  final int? id;

  /// UUID of the parent [WebSource].
  final String webSourceUuid;

  /// The experience text written by the user.
  final String text;

  /// When this entry was created (ms since epoch).
  final int createdAt;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final String uuid;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  WebSourceExperience({
    this.id,
    required this.webSourceUuid,
    required this.text,
    int? createdAt,
    String? uuid,
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       uuid = uuid ?? '',
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory WebSourceExperience.fromMap(Map<String, dynamic> map) {
    return WebSourceExperience(
      id: map['id'] as int?,
      webSourceUuid: (map['web_source_uuid'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      createdAt:
          (map['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      uuid: (map['uuid'] as String?) ?? '',
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
      deviceId: (map['device_id'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'web_source_uuid': webSourceUuid,
      'text': text,
      'created_at': createdAt,
      'uuid': uuid,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  WebSourceExperience copyWith({
    int? id,
    String? webSourceUuid,
    String? text,
    int? createdAt,
    String? uuid,
    int? updatedAt,
    int? deletedAt,
    String? deviceId,
  }) {
    return WebSourceExperience(
      id: id ?? this.id,
      webSourceUuid: webSourceUuid ?? this.webSourceUuid,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      uuid: uuid ?? this.uuid,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
