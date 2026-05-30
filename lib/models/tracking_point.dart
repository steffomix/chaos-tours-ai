class TrackingPoint {
  final int? id;
  final double lat;
  final double lng;
  final int timestamp;

  TrackingPoint({
    this.id,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  factory TrackingPoint.fromMap(Map<String, dynamic> map) {
    return TrackingPoint(
      id: map['id'] as int?,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'lat': lat,
      'lng': lng,
      'timestamp': timestamp,
    };
  }
}
