enum StayStatus { detecting, active, completed }

class Stay {
  final int? id;
  final int? placeId;
  final int startTime;
  final int? endTime;
  final String notes;
  final String? calendarEventId;
  final String? address;
  final StayStatus status;

  /// Whether this stay counts toward the interval scheduler.
  /// When false the visit is recorded normally but does not reset the interval.
  final bool isInterval;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final String uuid;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  Stay({
    this.id,
    this.placeId,
    required this.startTime,
    this.endTime,
    this.notes = '',
    this.calendarEventId,
    this.address,
    this.status = StayStatus.detecting,
    this.isInterval = true,
    String? uuid,
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
  }) : uuid = uuid ?? '',
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  bool get isActive => status != StayStatus.completed;

  DateTime get startDateTime => DateTime.fromMillisecondsSinceEpoch(startTime);
  DateTime? get endDateTime =>
      endTime != null ? DateTime.fromMillisecondsSinceEpoch(endTime!) : null;

  Duration get duration {
    final end = endDateTime ?? DateTime.now();
    return end.difference(startDateTime);
  }

  factory Stay.fromMap(Map<String, dynamic> map) {
    return Stay(
      id: map['id'] as int?,
      placeId: map['place_id'] as int?,
      startTime: map['start_time'] as int,
      endTime: map['end_time'] as int?,
      notes: (map['notes'] as String?) ?? '',
      calendarEventId: map['calendar_event_id'] as String?,
      address: map['address'] as String?,
      status: StayStatus.values.firstWhere(
        (s) => s.name == (map['status'] as String? ?? 'detecting'),
        orElse: () => StayStatus.detecting,
      ),
      isInterval: (map['is_interval'] as int? ?? 1) == 1,
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
      if (placeId != null) 'place_id': placeId,
      'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      'notes': notes,
      if (calendarEventId != null) 'calendar_event_id': calendarEventId,
      if (address != null) 'address': address,
      'status': status.name,
      'is_interval': isInterval ? 1 : 0,
      'uuid': uuid,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  Stay copyWith({
    int? id,
    int? placeId,
    int? startTime,
    int? endTime,
    String? notes,
    String? calendarEventId,
    String? address,
    StayStatus? status,
    bool? isInterval,
    bool clearEndTime = false,
    bool clearPlaceId = false,
    bool clearCalendarEventId = false,
    String? uuid,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return Stay(
      id: id ?? this.id,
      placeId: clearPlaceId ? null : (placeId ?? this.placeId),
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      notes: notes ?? this.notes,
      calendarEventId: clearCalendarEventId
          ? null
          : (calendarEventId ?? this.calendarEventId),
      address: address ?? this.address,
      status: status ?? this.status,
      isInterval: isInterval ?? this.isInterval,
      uuid: uuid ?? this.uuid,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
