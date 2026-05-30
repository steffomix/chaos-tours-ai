class Person {
  final int? id;
  final String name;
  final String role;

  Person({this.id, required this.name, this.role = ''});

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as int?,
      name: map['name'] as String,
      role: (map['role'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'name': name, 'role': role};
  }

  Person copyWith({int? id, String? name, String? role}) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }
}
