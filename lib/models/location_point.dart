class LocationPoint {
  final int? id;
  final int tourId;
  final double lat;
  final double lng;
  final int timestamp;

  LocationPoint({
    this.id,
    required this.tourId,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      id: map['id'] as int?,
      tourId: map['tour_id'] as int,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      timestamp: map['timestamp'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tour_id': tourId,
      'lat': lat,
      'lng': lng,
      'timestamp': timestamp,
    };
  }
}
