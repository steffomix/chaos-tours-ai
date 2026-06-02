/// One row in the tracking_log table — a snapshot of the engine state
/// for every processed GPS point.
class TrackingLogEntry {
  final int? id;

  /// Timestamp of the GPS point (ms since epoch).
  final int ts;

  final String prevStatus;
  final String newStatus;

  // Short-window metrics
  final int shortPts;
  final bool shortFull;
  final bool shortCluster;

  // Long-window metrics (0/false when long window was not evaluated)
  final int longPts;
  final bool longFull;
  final bool longCluster;

  /// ID of the nearest known place (null if none matched).
  final int? placeId;

  /// Short label describing what the engine did this tick.
  final String action;

  const TrackingLogEntry({
    this.id,
    required this.ts,
    required this.prevStatus,
    required this.newStatus,
    required this.shortPts,
    required this.shortFull,
    required this.shortCluster,
    required this.longPts,
    required this.longFull,
    required this.longCluster,
    this.placeId,
    required this.action,
  });

  factory TrackingLogEntry.fromMap(Map<String, dynamic> map) {
    return TrackingLogEntry(
      id: map['id'] as int?,
      ts: map['ts'] as int,
      prevStatus: map['prev_status'] as String,
      newStatus: map['new_status'] as String,
      shortPts: map['short_pts'] as int,
      shortFull: (map['short_full'] as int) == 1,
      shortCluster: (map['short_cluster'] as int) == 1,
      longPts: map['long_pts'] as int,
      longFull: (map['long_full'] as int) == 1,
      longCluster: (map['long_cluster'] as int) == 1,
      placeId: map['place_id'] as int?,
      action: map['action'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'ts': ts,
      'prev_status': prevStatus,
      'new_status': newStatus,
      'short_pts': shortPts,
      'short_full': shortFull ? 1 : 0,
      'short_cluster': shortCluster ? 1 : 0,
      'long_pts': longPts,
      'long_full': longFull ? 1 : 0,
      'long_cluster': longCluster ? 1 : 0,
      if (placeId != null) 'place_id': placeId,
      'action': action,
    };
  }
}
