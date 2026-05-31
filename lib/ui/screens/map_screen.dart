import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/saved_place.dart';
import '../../models/tracking_point.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/settings_service.dart';
import '../../services/test_mode_service.dart';
import '../../services/tracking_engine.dart';
import '../widgets/place_bottom_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<SavedPlace> _places = [];
  final MapController _mapController = MapController();
  final LayerHitNotifier<SavedPlace> _hitNotifier = ValueNotifier(null);

  // ── Live tracking points (always on) ───────────────────────────────────
  List<TrackingPoint> _trackingPoints = [];
  Timer? _liveRefreshTimer;

  // ── Test Mode (debug only) ────────────────────────────────────────────────
  Timer? _testTimer;
  int _simulatedNow = 0;
  TestModeState? _testState;
  bool _showLog = true;
  final ScrollController _logScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _loadTrackingPoints();
    // Refresh live tracking points every 15 s (matches GPS interval default).
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!kDebugMode || !TestModeService.instance.isActive) {
        _loadTrackingPoints();
      }
    });
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    _liveRefreshTimer?.cancel();
    _logScroll.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    final places = await DatabaseService.instance.loadAllPlaces();
    if (mounted) setState(() => _places = places);
  }

  Future<void> _loadTrackingPoints() async {
    final settings = SettingsService.instance;
    final since =
        DateTime.now().millisecondsSinceEpoch -
        (settings.autoPlaceSeconds + 120) * 1000;
    final pts = await DatabaseService.instance.loadTrackingPointsSince(since);
    if (mounted) setState(() => _trackingPoints = pts);
  }

  void _onCircleTap() {
    final hit = _hitNotifier.value;
    if (hit == null || hit.hitValues.isEmpty) return;
    final place = hit.hitValues.first;
    _showPlaceSheet(place);
  }

  Future<void> _onLongPress(TapPosition _, LatLng latlng) async {
    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neuer Ort'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final newPlace = SavedPlace(
      name: name,
      lat: latlng.latitude,
      lng: latlng.longitude,
    );
    await DatabaseService.instance.insertPlace(newPlace);
    await _loadPlaces();
  }

  void _showPlaceSheet(SavedPlace place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PlaceBottomSheet(
        place: place,
        onUpdated: _loadPlaces,
        onDeleted: _loadPlaces,
      ),
    );
  }

  Future<void> _goToCurrentLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    }
  }

  // ── Test Mode ────────────────────────────────────────────────────────────

  Future<void> _toggleTestMode() async {
    if (TestModeService.instance.isActive) {
      await _stopTestMode();
    } else {
      await _startTestMode();
    }
  }

  Future<void> _startTestMode() async {
    await TestModeService.instance.startTest();
    _simulatedNow = DateTime.now().millisecondsSinceEpoch;
    setState(() {});

    _testTimer = Timer.periodic(
      const Duration(milliseconds: TestModeService.tickIntervalMs),
      (_) async {
        _simulatedNow += TestModeService.simAdvancePerTickMs;
        LatLng center;
        try {
          center = _mapController.camera.center;
        } catch (_) {
          return; // map not yet attached
        }
        final state = await TestModeService.instance.tick(
          center.latitude,
          center.longitude,
          _simulatedNow,
        );
        if (!mounted) return;
        if (state.newPlaceAdded) await _loadPlaces();
        setState(() => _testState = state);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScroll.hasClients) {
            _logScroll.animateTo(
              _logScroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
            );
          }
        });
      },
    );
  }

  Future<void> _stopTestMode() async {
    _testTimer?.cancel();
    _testTimer = null;
    await TestModeService.instance.stopTest();
    if (mounted) setState(() => _testState = null);
  }

  // ── Status display helpers ────────────────────────────────────────────────

  Color _statusColor(TrackingStatus s) => switch (s) {
    TrackingStatus.idle => Colors.grey,
    TrackingStatus.moving => Colors.blue,
    TrackingStatus.detectingHalt => Colors.orange,
    TrackingStatus.haltAtKnown => Colors.green,
    TrackingStatus.haltAtUnknown => Colors.amber.shade700,
  };

  String _statusLabel(TrackingStatus s) => switch (s) {
    TrackingStatus.idle => 'Idle',
    TrackingStatus.moving => 'Bewegt',
    TrackingStatus.detectingHalt => 'Halt erkannt…',
    TrackingStatus.haltAtKnown => 'Halt – bekannt',
    TrackingStatus.haltAtUnknown => 'Halt – unbekannt',
  };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final testActive = kDebugMode && TestModeService.instance.isActive;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chaos Tours – Karte'),
        actions: [
          if (kDebugMode) ...[
            if (testActive && _testState != null)
              IconButton(
                icon: Icon(
                  _showLog ? Icons.terminal : Icons.terminal_outlined,
                  color: _showLog ? Colors.greenAccent : null,
                ),
                tooltip: 'Log ein/aus',
                onPressed: () => setState(() => _showLog = !_showLog),
              ),
            IconButton(
              icon: Icon(
                testActive ? Icons.stop_circle : Icons.play_circle_outline,
                color: testActive ? Colors.red : Colors.orange,
              ),
              tooltip: testActive ? 'Test stoppen' : 'Testmodus starten',
              onPressed: _toggleTestMode,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPlaces,
            tooltip: 'Orte neu laden',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onTapUp: (_) => _onCircleTap(),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(48.1351, 11.5820),
                      initialZoom: 13,
                      onLongPress: _onLongPress,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'de.chaostours.chaos_tours_ai',
                      ),
                      // Saved places layer
                      CircleLayer<SavedPlace>(
                        hitNotifier: _hitNotifier,
                        circles: _places.map((place) {
                          final colorType = place.placeColorType;
                          return CircleMarker<SavedPlace>(
                            hitValue: place,
                            point: LatLng(place.lat, place.lng),
                            radius: place.radius,
                            useRadiusInMeter: true,
                            color: colorType.color,
                            borderColor: colorType.borderColor,
                            borderStrokeWidth: 2,
                          );
                        }).toList(),
                      ),
                      // Tracking-points layer: test-categorised in debug,
                      // live DB points in release.
                      if (testActive && _testState != null)
                        _buildTestTrackingLayer(_testState!)
                      else
                        _buildLiveTrackingLayer(),
                    ],
                  ),
                ),
                // Status overlay (top-left corner)
                if (testActive && _testState != null)
                  _buildStatusOverlay(_testState!),
              ],
            ),
          ),
          // Log panel (below map)
          if (testActive && _showLog && _testState != null)
            _buildLogPanel(_testState!),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCurrentLocation,
        tooltip: 'Zu meiner Position',
        child: const Icon(Icons.my_location),
      ),
    );
  }

  /// Live tracking points layer (always visible, from the real DB).
  Widget _buildLiveTrackingLayer() {
    return CircleLayer(
      circles: _trackingPoints
          .map(
            (p) => CircleMarker(
              point: LatLng(p.lat, p.lng),
              radius: 2,
              useRadiusInMeter: true,
              color: Colors.black54,
              borderColor: Colors.black87,
              borderStrokeWidth: 1,
            ),
          )
          .toList(),
    );
  }

  /// Categorised tracking-points layer used in debug test mode.
  Widget _buildTestTrackingLayer(TestModeState state) {
    final circles = <CircleMarker>[];

    // Long-only window → light gray
    for (final p in state.longOnlyPoints) {
      circles.add(
        CircleMarker(
          point: LatLng(p.lat, p.lng),
          radius: 2,
          useRadiusInMeter: true,
          color: Colors.grey.shade300.withAlpha(200),
          borderColor: Colors.grey.shade500,
          borderStrokeWidth: 1,
        ),
      );
    }

    // Short window → black
    for (final p in state.shortWindowPoints) {
      circles.add(
        CircleMarker(
          point: LatLng(p.lat, p.lng),
          radius: 2,
          useRadiusInMeter: true,
          color: Colors.black.withAlpha(180),
          borderColor: Colors.black,
          borderStrokeWidth: 1,
        ),
      );
    }

    // Cluster centroid → red
    if (state.clusterCentroid != null) {
      circles.add(
        CircleMarker(
          point: LatLng(state.clusterCentroid!.lat, state.clusterCentroid!.lng),
          radius: 3,
          useRadiusInMeter: true,
          color: Colors.red.withAlpha(230),
          borderColor: Colors.red.shade900,
          borderStrokeWidth: 2,
        ),
      );
    }

    return CircleLayer(circles: circles);
  }

  /// Small status card shown on top of the map in test mode.
  Widget _buildStatusOverlay(TestModeState state) {
    final color = _statusColor(state.status);
    return Positioned(
      top: 8,
      left: 8,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withAlpha(230),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 10, color: color),
                  const SizedBox(width: 6),
                  Text(
                    _statusLabel(state.status),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'K: ${state.shortWindowCount}Pt '
                '${state.shortIsFull ? "✓" : "…"}'
                '${state.shortIsCluster ? "●" : "○"}  '
                'L: ${state.longWindowCount}Pt '
                '${state.longIsFull ? "✓" : "…"}'
                '${state.longIsCluster ? "●" : "○"}',
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Scrollable log panel below the map.
  Widget _buildLogPanel(TestModeState state) {
    return SizedBox(
      height: 180,
      child: Container(
        color: const Color(0xFF1A1A1A),
        child: Column(
          children: [
            // Header bar
            Container(
              height: 24,
              color: const Color(0xFF2D2D2D),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Text(
                    'TEST LOG',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${state.logLines.length} Zeilen',
                    style: const TextStyle(color: Colors.white30, fontSize: 10),
                  ),
                ],
              ),
            ),
            // Log lines
            Expanded(
              child: ListView.builder(
                controller: _logScroll,
                itemCount: state.logLines.length,
                itemBuilder: (_, i) {
                  final line = state.logLines[i];
                  final isStatus = line.contains('▶') || line.contains('===');
                  final isStay = line.contains('➕') || line.contains('⬛');
                  Color textColor = Colors.green.shade300;
                  if (isStatus) textColor = Colors.cyan.shade300;
                  if (isStay) textColor = Colors.yellow.shade300;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    child: Text(
                      line,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
