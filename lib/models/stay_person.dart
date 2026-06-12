class StayPerson {
  final int? id;
  final int stayId;
  final int? personId;
  final String name;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final String uuid;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  StayPerson({
    this.id,
    required this.stayId,
    this.personId,
    required this.name,
    String? uuid,
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
  }) : uuid = uuid ?? '',
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory StayPerson.fromMap(Map<String, dynamic> map) {
    return StayPerson(
      id: map['id'] as int?,
      stayId: map['stay_id'] as int,
      personId: map['person_id'] as int?,
      name: map['name'] as String,
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
      'stay_id': stayId,
      if (personId != null) 'person_id': personId,
      'name': name,
      'uuid': uuid,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }
}
