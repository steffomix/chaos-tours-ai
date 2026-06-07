import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/saved_place.dart';
import '../../models/tracking_point.dart';
import '../../services/database_service.dart';
import '../../services/foreground_service_handler.dart';
import '../../services/location_service.dart';
import '../../services/nominatim_service.dart';
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

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _loadTrackingPoints();
    // Move map to current location once the map controller is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToCurrentLocation());
    ForegroundServiceManager.addDataListener(_onServiceData);
  }

  @override
  void dispose() {
    ForegroundServiceManager.removeDataListener(_onServiceData);
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    final allPlaces = await DatabaseService.instance.loadAllPlaces();
    final groupFilter = SettingsService.instance.schedulerGroupIdList;
    final places = groupFilter.isEmpty
        ? allPlaces
        : allPlaces
              .where(
                (p) => p.groupId != null && groupFilter.contains(p.groupId),
              )
              .toList();
    if (mounted) setState(() => _places = places);
  }

  void _onServiceData(Object data) {
    _loadPlaces();
    _loadTrackingPoints();
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
      groupId: SettingsService.instance.defaultPlaceGroupId,
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
            icon: const Icon(Icons.search),
            onPressed: _showAddressSearch,
            tooltip: 'Adresse suchen',
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

  /// Address search sheet using Nominatim structured geocoding.
  void _showAddressSearch() {
    final countryCtrl = TextEditingController(
      text: SettingsService.instance.searchCountry,
    );
    final cityCtrl = TextEditingController();
    final streetCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return _AddressSearchSheet(
          countryCtrl: countryCtrl,
          cityCtrl: cityCtrl,
          streetCtrl: streetCtrl,
          onResultSelected: (result) {
            Navigator.pop(ctx);
            final pos = LatLng(result.lat, result.lng);
            _mapController.move(pos, 16);
            _showLocationActionSheet(pos, result.displayName);
          },
        );
      },
    );
  }

  /// Shown after the user taps a geocoding result — offers "create place" and
  /// "navigate with Google Maps".
  void _showLocationActionSheet(LatLng pos, String label) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                label,
                style: Theme.of(ctx).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_location_alt_outlined),
              title: const Text('Ort hier erstellen'),
              onTap: () {
                Navigator.pop(ctx);
                _onLongPress(const TapPosition(Offset.zero, Offset.zero), pos);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions),
              title: const Text('Route in Google Maps'),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1'
                  '&destination=${pos.latitude},${pos.longitude}',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
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

    final shortWindowPolyPoints = state.shortWindowPoints
        .map((p) => LatLng(p.lat, p.lng))
        .toList();

    final longOnlyPolyPoints = state.longOnlyPoints
        .map((p) => LatLng(p.lat, p.lng))
        .toList();

    // add last short window point before long-only points to connect the ploylibnes, if both are present
    if (state.shortWindowPoints.isNotEmpty && state.longOnlyPoints.isNotEmpty) {
      longOnlyPolyPoints.add(
        LatLng(
          state.shortWindowPoints.last.lat,
          state.shortWindowPoints.last.lng,
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

    return Stack(
      children: [
        CircleLayer(circles: circles),
        PolylineLayer(
          polylines: [
            Polyline(
              points: longOnlyPolyPoints,
              strokeWidth: 2.0,
              color: Colors.grey.shade400.withAlpha(180),
            ),
          ],
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: shortWindowPolyPoints,
              strokeWidth: 2.0,
              color: statusColor.withAlpha(180),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Address search bottom sheet ───────────────────────────────────────────────

class _AddressSearchSheet extends StatefulWidget {
  const _AddressSearchSheet({
    required this.countryCtrl,
    required this.cityCtrl,
    required this.streetCtrl,
    required this.onResultSelected,
  });

  final TextEditingController countryCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController streetCtrl;
  final ValueChanged<NominatimResult> onResultSelected;

  @override
  State<_AddressSearchSheet> createState() => _AddressSearchSheetState();
}

class _AddressSearchSheetState extends State<_AddressSearchSheet> {
  List<NominatimResult> _results = [];
  bool _searching = false;
  String? _error;

  Future<void> _search() async {
    final country = widget.countryCtrl.text.trim();
    final city = widget.cityCtrl.text.trim();
    final street = widget.streetCtrl.text.trim();

    if (country.isEmpty && city.isEmpty && street.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _results = [];
    });

    final results = await NominatimService.instance.searchAddress(
      country: country,
      city: city,
      street: street,
    );

    if (mounted) {
      setState(() {
        _searching = false;
        _results = results;
        if (results.isEmpty) _error = 'Keine Ergebnisse gefunden.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.search),
                const SizedBox(width: 8),
                Text(
                  'Adresse suchen',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                TextField(
                  controller: widget.countryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Land',
                    hintText: 'z. B. Deutschland',
                    prefixIcon: Icon(Icons.flag_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.cityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Stadt / Ort',
                    hintText: 'z. B. München',
                    prefixIcon: Icon(Icons.location_city),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.streetCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Straße (optional)',
                    hintText: 'z. B. Marienplatz 1',
                    prefixIcon: Icon(Icons.signpost_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Suchen'),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = _results[i];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(
                      r.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    dense: true,
                    onTap: () => widget.onResultSelected(r),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
