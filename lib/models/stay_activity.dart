class StayActivity {
  final int? id;
  final int stayId;
  final int? activityId;
  final String description;

  StayActivity({
    this.id,
    required this.stayId,
    this.activityId,
    required this.description,
  });

  factory StayActivity.fromMap(Map<String, dynamic> map) {
    return StayActivity(
      id: map['id'] as int?,
      stayId: map['stay_id'] as int,
      activityId: map['activity_id'] as int?,
      description: map['description'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'stay_id': stayId,
      if (activityId != null) 'activity_id': activityId,
      'description': description,
    };
  }
}
