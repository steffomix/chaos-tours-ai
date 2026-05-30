class Activity {
  final int? id;
  final String name;

  Activity({this.id, required this.name});

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(id: map['id'] as int?, name: map['name'] as String);
  }

  Map<String, dynamic> toMap() {
    return {if (id != null) 'id': id, 'name': name};
  }

  Activity copyWith({int? id, String? name}) {
    return Activity(id: id ?? this.id, name: name ?? this.name);
  }
}
