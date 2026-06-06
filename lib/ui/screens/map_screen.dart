import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/saved_place.dart';
import '../../models/tracking_point.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../services/settings_service.dart';
import '../../services/tracking_engine.dart';
import '../../utils/geo_utils.dart';
import '../widgets/place_bottom_sheet.dart';

/// Categorised live tracking state for the map layer.
class _LiveTrackingState {
  final TrackingStatus status;
  final List<TrackingPoint> shortWindowPoints;
  final List<TrackingPoint> longOnlyPoints;
  final ({double lat, double lng})? clusterCentroid;

  const _LiveTrackingState({
    required this.status,
    required this.shortWindowPoints,
    required this.longOnlyPoints,
    this.clusterCentroid,
  });
}

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
  _LiveTrackingState? _liveState;
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _loadTrackingPoints();
    // Move map to current location once the map controller is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToCurrentLocation());
    // Refresh live tracking points every 15 s (matches GPS interval default).
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadTrackingPoints();
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    final places = await DatabaseService.instance.loadAllPlaces();
    if (mounted) setState(() => _places = places);
  }

  Future<void> _loadTrackingPoints() async {
    final settings = SettingsService.instance;
    if (!settings.showTrackingPoints) {
      if (mounted) setState(() => _liveState = null);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final shortStart = now - settings.stayDetectionSeconds * 1000;
    final longStart = now - (settings.autoPlaceSeconds + 120) * 1000;

    final allPts = await DatabaseService.instance.loadTrackingPointsSince(
      longStart,
    );
    final shortPts = allPts.where((p) => p.timestamp >= shortStart).toList();
    final longOnlyPts = allPts.where((p) => p.timestamp < shortStart).toList();

    // Compute visual status from the short window.
    final shortGeo = shortPts.map((p) => (lat: p.lat, lng: p.lng)).toList();
    final shortIsCluster =
        shortGeo.isNotEmpty &&
        GeoUtils.isCluster(shortGeo, settings.defaultRadiusMeters);

    ({double lat, double lng})? centroid;
    TrackingStatus status;

    if (shortPts.isEmpty) {
      status = TrackingStatus.idle;
    } else if (!shortIsCluster) {
      status = TrackingStatus.moving;
    } else {
      centroid = GeoUtils.centroid(shortGeo);
      // Distinguish haltAtKnown vs haltAtUnknown by checking known places.
      bool nearKnown = false;
      for (final place in _places) {
        if (!place.placeType.tracksStay) continue;
        final dist = GeoUtils.distanceMeters(
          centroid.lat,
          centroid.lng,
          place.lat,
          place.lng,
        );
        if (dist <= place.radius) {
          nearKnown = true;
          break;
        }
      }
      // Use detectingHalt if the short window is not yet full.
      final shortFull =
          shortPts.isNotEmpty &&
          shortPts.first.timestamp <=
              shortStart + settings.gpsIntervalSeconds * 1000;
      if (!shortFull) {
        status = TrackingStatus.detectingHalt;
      } else {
        status = nearKnown
            ? TrackingStatus.haltAtKnown
            : TrackingStatus.haltAtUnknown;
      }
    }

    if (mounted) {
      setState(
        () => _liveState = _LiveTrackingState(
          status: status,
          shortWindowPoints: shortPts,
          longOnlyPoints: longOnlyPts,
          clusterCentroid: centroid,
        ),
      );
    }
  }

  void _onMapTap(TapPosition _, LatLng __) {
    final hit = _hitNotifier.value;
    if (hit == null || hit.hitValues.isEmpty) return;
    if (hit.hitValues.length == 1) {
      _showPlaceSheet(hit.hitValues.first);
      return;
    }
    // Multiple overlapping circles — let the user pick one.
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Welchen Ort öffnen?',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          ...hit.hitValues.map(
            (p) => ListTile(
              leading: Icon(p.placeType.icon, color: p.placeType.dotColor),
              title: Text(p.name),
              onTap: () {
                Navigator.pop(ctx);
                _showPlaceSheet(p);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
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
      useSafeArea: true,
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

  // ── Status display helpers ────────────────────────────────────────────────

  Color _statusColor(TrackingStatus s) => switch (s) {
    TrackingStatus.idle => Colors.grey,
    TrackingStatus.moving => Colors.blue,
    TrackingStatus.detectingHalt => Colors.orange,
    TrackingStatus.haltAtKnown => Colors.green,
    TrackingStatus.haltAtUnknown => Colors.amber.shade700,
  };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chaos Tours – Karte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
            tooltip: 'Aktuellen Standort anzeigen',
          ),
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
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(48.1351, 11.5820),
                    initialZoom: 13,
                    onTap: _onMapTap,
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
                      circles: _places
                          .where(
                            (p) =>
                                p.placeType != PlaceType.forbidden ||
                                SettingsService.instance.showForbiddenPlaces,
                          )
                          .map((place) {
                            return CircleMarker<SavedPlace>(
                              hitValue: place,
                              point: LatLng(place.lat, place.lng),
                              radius: place.radius,
                              useRadiusInMeter: true,
                              color: place.placeType.fillColor,
                              borderColor: place.placeType.dotColor,
                              borderStrokeWidth: 2,
                            );
                          })
                          .toList(),
                    ),
                    _buildLiveTrackingLayer(),
                  ],
                ),
              ],
            ),
          ),
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
    final state = _liveState;
    if (state == null) return const SizedBox.shrink();

    final settings = SettingsService.instance;
    final r = settings.trackingPointRadius;
    final statusColor = _statusColor(state.status);
    final circles = <CircleMarker>[];

    // Long-only window → gray
    for (final p in state.longOnlyPoints) {
      circles.add(
        CircleMarker(
          point: LatLng(p.lat, p.lng),
          radius: r,
          useRadiusInMeter: true,
          color: Colors.grey.shade400.withAlpha(180),
          borderColor: Colors.grey.shade600,
          borderStrokeWidth: 1,
        ),
      );
    }

    // Short window → status color
    for (final p in state.shortWindowPoints) {
      circles.add(
        CircleMarker(
          point: LatLng(p.lat, p.lng),
          radius: r,
          useRadiusInMeter: true,
          color: statusColor.withAlpha(180),
          borderColor: statusColor,
          borderStrokeWidth: 1,
        ),
      );
    }

    // Cluster centroid → red
    if (state.clusterCentroid != null) {
      final c = state.clusterCentroid!;
      circles.add(
        CircleMarker(
          point: LatLng(c.lat, c.lng),
          radius: r,
          useRadiusInMeter: true,
          color: Colors.red.withAlpha(230),
          borderColor: Colors.red.shade900,
          borderStrokeWidth: 2,
        ),
      );
    }

    return CircleLayer(circles: circles);
  }
}
