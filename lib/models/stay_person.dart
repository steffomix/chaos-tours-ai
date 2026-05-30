class StayPerson {
  final int? id;
  final int stayId;
  final int? personId;
  final String name;

  StayPerson({
    this.id,
    required this.stayId,
    this.personId,
    required this.name,
  });

  factory StayPerson.fromMap(Map<String, dynamic> map) {
    return StayPerson(
      id: map['id'] as int?,
      stayId: map['stay_id'] as int,
      personId: map['person_id'] as int?,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'stay_id': stayId,
      if (personId != null) 'person_id': personId,
      'name': name,
    };
  }
}
