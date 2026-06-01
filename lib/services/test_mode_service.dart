import '../models/tracking_point.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/tracking_engine.dart';
import '../utils/geo_utils.dart';

/// Snapshot of the test mode state emitted after each simulated GPS tick.
class TestModeState {
  final TrackingStatus status;
  final String? notificationText;

  /// Points within the short detection window (stayDetectionSeconds) → drawn black.
  final List<TrackingPoint> shortWindowPoints;

  /// Points in the long window (autoPlaceSeconds) that are NOT in the short
  /// window → drawn light gray.
  final List<TrackingPoint> longOnlyPoints;

  /// Centroid of the currently active cluster (short window if cluster,
  /// else long window if cluster) → drawn red.
  final ({double lat, double lng})? clusterCentroid;

  /// Diagnostic counts and flags for the log panel.
  final int shortWindowCount;
  final int longWindowCount;
  final bool shortIsFull;
  final bool shortIsCluster;
  final bool longIsFull;
  final bool longIsCluster;

  /// Accumulated log lines (latest at the end, capped at 200).
  final List<String> logLines;

  /// True if a new [SavedPlace] was persisted during this tick.
  final bool newPlaceAdded;

  const TestModeState({
    required this.status,
    this.notificationText,
    required this.shortWindowPoints,
    required this.longOnlyPoints,
    this.clusterCentroid,
    required this.shortWindowCount,
    required this.longWindowCount,
    required this.shortIsFull,
    required this.shortIsCluster,
    required this.longIsFull,
    required this.longIsCluster,
    required this.logLines,
    this.newPlaceAdded = false,
  });
}

/// Drives the [TrackingEngine] with simulated GPS data for testing.
///
/// Usage (from a [StatefulWidget]):
///
/// ```dart
/// // Start:
/// await TestModeService.instance.startTest();
///
/// // Each tick (call from a Timer.periodic(500 ms)):
/// final center = _mapController.camera.center;
/// final state = await TestModeService.instance.tick(
///   center.latitude, center.longitude, _simulatedNow);
///
/// // Stop:
/// await TestModeService.instance.stopTest();
/// ```
///
/// The caller is responsible for advancing [simulatedNow] by
/// [tickIntervalMs] × [speedFactor] per tick (= 500 ms × 30 = 15 000 ms).
class TestModeService {
  TestModeService._();
  static final TestModeService instance = TestModeService._();

  /// Each real-time tick advances the simulated clock by this factor.
  static const int speedFactor = 30;

  /// Real-time interval between ticks in milliseconds.
  static const int tickIntervalMs = 500;

  /// Simulated time advance per tick in milliseconds.
  static const int simAdvancePerTickMs =
      tickIntervalMs * speedFactor; // 15 000 ms

  // Dedicated engine instance for test mode (isolated from the live service).
  final _engine = TrackingEngine();

  bool _isActive = false;
  TrackingStatus? _lastStatus;
  int? _lastStayId;
  int _tickCount = 0;
  final List<String> _log = [];

  bool get isActive => _isActive;

  /// Clears rolling tracking points and resets the engine.
  /// Call once before starting the timer loop.
  Future<void> startTest() async {
    if (_isActive) return;
    _isActive = true;
    _tickCount = 0;
    _log.clear();
    _lastStatus = null;
    _lastStayId = null;

    // Clear the rolling tracking points so the engine starts fresh.
    await DatabaseService.instance.deleteAllTrackingPoints();
    await _engine.initialize();

    final settings = SettingsService.instance;
    _addLog('=== Test gestartet ===');
    _addLog(
      'Kurzfenster: ${settings.stayDetectionSeconds}s (real: '
      '${(settings.stayDetectionSeconds / speedFactor).toStringAsFixed(1)}s) | '
      'Langfenster: ${settings.autoPlaceSeconds}s (real: '
      '${(settings.autoPlaceSeconds / speedFactor).toStringAsFixed(1)}s)',
    );
    _addLog('Radius: ${settings.defaultRadiusMeters.toStringAsFixed(0)} m');
  }

  /// Process one simulated GPS tick and return the new [TestModeState].
  ///
  /// [lat], [lng]: current map-centre position.
  /// [simulatedNow]: simulated epoch timestamp in milliseconds.
  Future<TestModeState> tick(double lat, double lng, int simulatedNow) async {
    assert(_isActive, 'Call startTest() before tick()');

    _tickCount++;
    // Snapshot place count before so we can detect auto-created places.
    final placesBefore =
        (await DatabaseService.instance.loadAllPlaces()).length;
    final result = await _engine.onNewPoint(lat, lng, simulatedNow);
    final placesAfter = (await DatabaseService.instance.loadAllPlaces()).length;
    final newPlaceAdded = placesAfter > placesBefore;

    final settings = SettingsService.instance;
    final shortStart = simulatedNow - settings.stayDetectionSeconds * 1000;
    final longStart = simulatedNow - settings.autoPlaceSeconds * 1000;

    final shortPts = await DatabaseService.instance.loadTrackingPointsSince(
      shortStart,
    );
    final allLongPts = await DatabaseService.instance.loadTrackingPointsSince(
      longStart,
    );

    // Separate long-only points (not overlapping with short window).
    final shortIds = shortPts.map((p) => p.id).toSet();
    final longOnlyPts = allLongPts
        .where((p) => !shortIds.contains(p.id))
        .toList();

    // Cluster detection.
    final shortCoords = shortPts.map((p) => (lat: p.lat, lng: p.lng)).toList();
    final allLongCoords = allLongPts
        .map((p) => (lat: p.lat, lng: p.lng))
        .toList();

    final shortIsFull =
        shortPts.isNotEmpty &&
        (simulatedNow - shortPts.first.timestamp) >=
            settings.stayDetectionSeconds * 1000;
    final longIsFull =
        allLongPts.isNotEmpty &&
        (simulatedNow - allLongPts.first.timestamp) >=
            settings.autoPlaceSeconds * 1000;

    final shortIsCluster =
        shortPts.length >= 2 &&
        GeoUtils.isCluster(shortCoords, settings.defaultRadiusMeters);
    final longIsCluster =
        allLongPts.length >= 2 &&
        GeoUtils.isCluster(allLongCoords, settings.defaultRadiusMeters);

    // Pick centroid: prefer short window cluster, fall back to long.
    ({double lat, double lng})? centroid;
    if (shortIsCluster) {
      centroid = GeoUtils.centroid(shortCoords);
    } else if (longIsCluster) {
      centroid = GeoUtils.centroid(allLongCoords);
    }

    final timeStr = _formatSimTime(simulatedNow);

    // Log status changes.
    if (result.status != _lastStatus) {
      _lastStatus = result.status;
      _addLog('[$timeStr] ▶ ${_statusLabel(result.status)}');
      if (result.notificationText != null) {
        _addLog('   ${result.notificationText}');
      }
    }

    // Log stay changes.
    final stayId = result.currentStay?.id;
    if (stayId != _lastStayId) {
      if (stayId != null && _lastStayId == null) {
        _addLog(
          '[$timeStr] ➕ Stay gestartet'
          '${result.currentPlace != null ? " @ ${result.currentPlace!.name}" : ""}',
        );
      } else if (stayId == null && _lastStayId != null) {
        _addLog('[$timeStr] ⬛ Stay beendet');
      }
      _lastStayId = stayId;
    }

    // Log newly created place.
    if (newPlaceAdded) {
      final newPlaces = await DatabaseService.instance.loadAllPlaces();
      final newest = newPlaces.last;
      _addLog(
        '[$timeStr] 📍 Neuer Ort: "${newest.name}" (${newest.lat.toStringAsFixed(5)}, ${newest.lng.toStringAsFixed(5)})',
      );
    }

    // Per-tick diagnostics (every tick for visibility).
    _addLog(
      '[$timeStr] '
      'K:${shortPts.length}Pt${shortIsFull ? "✓" : "…"}${shortIsCluster ? "●" : "○"} '
      'L:${allLongPts.length}Pt${longIsFull ? "✓" : "…"}${longIsCluster ? "●" : "○"} '
      '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}',
    );

    if (_log.length > 200) {
      _log.removeRange(0, _log.length - 200);
    }

    return TestModeState(
      status: result.status,
      notificationText: result.notificationText,
      shortWindowPoints: shortPts,
      longOnlyPoints: longOnlyPts,
      clusterCentroid: centroid,
      shortWindowCount: shortPts.length,
      longWindowCount: allLongPts.length,
      shortIsFull: shortIsFull,
      shortIsCluster: shortIsCluster,
      longIsFull: longIsFull,
      longIsCluster: longIsCluster,
      logLines: List.unmodifiable(_log),
      newPlaceAdded: newPlaceAdded,
    );
  }

  /// Ends any open stay and marks the service as inactive.
  Future<void> stopTest() async {
    _isActive = false;
    await _engine.stopTracking();
    _addLog('=== Test gestoppt ($_tickCount Ticks) ===');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatSimTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _statusLabel(TrackingStatus s) => switch (s) {
    TrackingStatus.idle => 'Idle',
    TrackingStatus.moving => 'Bewegt',
    TrackingStatus.detectingHalt => 'Halt erkannt…',
    TrackingStatus.haltAtKnown => 'Halt – bekannter Ort',
    TrackingStatus.haltAtUnknown => 'Halt – unbekannter Ort',
  };

  void _addLog(String msg) => _log.add(msg);
}
