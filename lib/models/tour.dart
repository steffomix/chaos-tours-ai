class Tour {
  final int? id;
  final String name;
  final int startTime;
  final int? endTime;
  final String? calendarEventId;

  Tour({
    this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    this.calendarEventId,
  });

  bool get isRunning => endTime == null;

  DateTime get startDateTime => DateTime.fromMillisecondsSinceEpoch(startTime);
  DateTime? get endDateTime =>
      endTime != null ? DateTime.fromMillisecondsSinceEpoch(endTime!) : null;

  factory Tour.fromMap(Map<String, dynamic> map) {
    return Tour(
      id: map['id'] as int?,
      name: map['name'] as String,
      startTime: map['start_time'] as int,
      endTime: map['end_time'] as int?,
      calendarEventId: map['calendar_event_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (calendarEventId != null) 'calendar_event_id': calendarEventId,
    };
  }

  Tour copyWith({
    int? id,
    String? name,
    int? startTime,
    int? endTime,
    String? calendarEventId,
    bool clearEndTime = false,
    bool clearCalendarEventId = false,
  }) {
    return Tour(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      calendarEventId: clearCalendarEventId
          ? null
          : (calendarEventId ?? this.calendarEventId),
    );
  }
}
