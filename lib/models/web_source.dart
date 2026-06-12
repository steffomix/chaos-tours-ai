/// A remote URL that provides exportable place data.
/// Used for importing places from other devices or public sources.
class WebSource {
  final int? id;

  /// Display name for this source.
  final String name;

  /// Base URL of the remote service (e.g. http://192.168.1.10:8000).
  final String url;

  /// Optional notes about this source.
  final String notes;

  /// Personal experience / review for this source.
  final String experience;

  /// API key for authenticating against the remote service.
  final String apiKey;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final String uuid;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  WebSource({
    this.id,
    required this.name,
    required this.url,
    this.notes = '',
    this.experience = '',
    this.apiKey = '',
    String? uuid,
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
  }) : uuid = uuid ?? '',
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory WebSource.fromMap(Map<String, dynamic> map) {
    return WebSource(
      id: map['id'] as int?,
      name: map['name'] as String,
      url: map['url'] as String,
      notes: (map['notes'] as String?) ?? '',
      experience: (map['experience'] as String?) ?? '',
      apiKey: (map['api_key'] as String?) ?? '',
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
      'name': name,
      'url': url,
      'notes': notes,
      'experience': experience,
      'api_key': apiKey,
      'uuid': uuid,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  WebSource copyWith({
    int? id,
    String? name,
    String? url,
    String? notes,
    String? experience,
    String? apiKey,
    String? uuid,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return WebSource(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      experience: experience ?? this.experience,
      apiKey: apiKey ?? this.apiKey,
      uuid: uuid ?? this.uuid,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
