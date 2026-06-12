class Person {
  final int? id;
  final String name;
  final String role;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final String uuid;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  Person({
    this.id,
    required this.name,
    this.role = '',
    String? uuid,
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
  }) : uuid = uuid ?? '',
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as int?,
      name: map['name'] as String,
      role: (map['role'] as String?) ?? '',
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
      'role': role,
      'uuid': uuid,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  Person copyWith({
    int? id,
    String? name,
    String? role,
    String? uuid,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      uuid: uuid ?? this.uuid,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
