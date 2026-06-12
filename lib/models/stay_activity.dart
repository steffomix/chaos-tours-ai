class StayActivity {
  final int? id;
  final int stayId;
  final int? activityId;
  final String description;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final String uuid;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  StayActivity({
    this.id,
    required this.stayId,
    this.activityId,
    required this.description,
    String? uuid,
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
  }) : uuid = uuid ?? '',
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory StayActivity.fromMap(Map<String, dynamic> map) {
    return StayActivity(
      id: map['id'] as int?,
      stayId: map['stay_id'] as int,
      activityId: map['activity_id'] as int?,
      description: map['description'] as String,
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
      if (activityId != null) 'activity_id': activityId,
      'description': description,
      'uuid': uuid,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }
}
