class PlaceGroup {
  final int? id;
  final String name;
  final String? calendarId;
  final bool includeNotes;
  final bool includePersons;
  final bool includeActivities;
  final bool isAutoGroup;

  PlaceGroup({
    this.id,
    required this.name,
    this.calendarId,
    this.includeNotes = true,
    this.includePersons = true,
    this.includeActivities = true,
    this.isAutoGroup = false,
  });

  factory PlaceGroup.fromMap(Map<String, dynamic> map) {
    return PlaceGroup(
      id: map['id'] as int?,
      name: map['name'] as String,
      calendarId: map['calendar_id'] as String?,
      includeNotes: (map['include_notes'] as int? ?? 1) == 1,
      includePersons: (map['include_persons'] as int? ?? 1) == 1,
      includeActivities: (map['include_activities'] as int? ?? 1) == 1,
      isAutoGroup: (map['is_auto_group'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (calendarId != null) 'calendar_id': calendarId,
      'include_notes': includeNotes ? 1 : 0,
      'include_persons': includePersons ? 1 : 0,
      'include_activities': includeActivities ? 1 : 0,
      'is_auto_group': isAutoGroup ? 1 : 0,
    };
  }

  PlaceGroup copyWith({
    int? id,
    String? name,
    String? calendarId,
    bool? includeNotes,
    bool? includePersons,
    bool? includeActivities,
    bool? isAutoGroup,
    bool clearCalendarId = false,
  }) {
    return PlaceGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      calendarId: clearCalendarId ? null : (calendarId ?? this.calendarId),
      includeNotes: includeNotes ?? this.includeNotes,
      includePersons: includePersons ?? this.includePersons,
      includeActivities: includeActivities ?? this.includeActivities,
      isAutoGroup: isAutoGroup ?? this.isAutoGroup,
    );
  }
}
