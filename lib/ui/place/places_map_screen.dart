import 'dart:math';

import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/saved_place.dart';
import '../../models/tracking_point.dart';
import '../../services/database_service.dart';
import '../../services/foreground_service_handler.dart';
import '../../services/location_service.dart';
import '../../services/settings_service.dart';
import '../../services/tracking_engine.dart';
import '../../utils/geo_utils.dart';
import '../../utils/place_creation_helper.dart';
import 'places_filter_panel.dart';
import 'place_detail_screen.dart';
import 'place_map_address_search.dart';

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

class PlacesMapScreen extends StatefulWidget {
  const PlacesMapScreen({super.key});

  @override
  State<PlacesMapScreen> createState() => _PlacesMapScreenState();
}

class _PlacesMapScreenState extends State<PlacesMapScreen> {
  List<SavedPlace> _places = [];
  Map<String, double> _avgRatings = {};
  final MapController _mapController = MapController();
  final LayerHitNotifier<SavedPlace> _hitNotifier = ValueNotifier(null);

  // ── Experience / distance filter ────────────────────────────────────────
  bool _filterPanelOpen = false;
  PlacesFilterState _expFilter = const PlacesFilterState();
  ({double lat, double lng})? _currentPos;

  // ── Live tracking points (always on) ───────────────────────────────────
  _LiveTrackingState? _liveState;

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _expFilter = PlacesFilterState(
      ownDeviceOnly: s.filterRequireExperiences,
      minAvgRating: s.filterMinAvgRating,
      distanceEnabled: s.filterDistanceEnabled,
      maxDistanceKm: s.filterMaxDistanceKm,
    );
    _loadPlaces();
    _loadTrackingPoints();
    // Move map to current location once the map controller is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToCurrentLocation());
  }

  @override
  void dispose() {
    ForegroundServiceManager.removeDataListener(_onServiceData);
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    // Update current position for distance filter.
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null && mounted) {
        _currentPos = (lat: pos.latitude, lng: pos.longitude);
      }
    } catch (_) {}

    final pos = _currentPos;
    final List<SavedPlace> places;
    if (_expFilter.distanceEnabled && pos != null) {
      final maxM = _expFilter.maxDistanceKm * 1000;
      final latDelta = maxM / 111000;
      final lngDelta =
          maxM / (111000 * cos(pos.lat * pi / 180).abs().clamp(0.001, 1.0));
      places = await DatabaseService.instance.loadPlacesWithinBounds(
        minLat: pos.lat - latDelta,
        maxLat: pos.lat + latDelta,
        minLng: pos.lng - lngDelta,
        maxLng: pos.lng + lngDelta,
      );
    } else {
      places = await DatabaseService.instance.loadAllPlaces();
    }
    final avgRatings = await DatabaseService.instance
        .loadAverageRatingsForAllPlaces();

    if (mounted) {
      setState(() {
        _places = _applyFilter(places);
        _avgRatings = avgRatings;
      });
    }
  }

  List<SavedPlace> _applyFilter(List<SavedPlace> places) {
    if (!_expFilter.isActive && !_expFilter.distanceEnabled) return places;
    final pos = _currentPos;

    List<SavedPlace> filtered = places;

    // Experience filter.
    if (_expFilter.isActive) {
      filtered = filtered.where((p) {
        if (p.uuid.isEmpty) return !_expFilter.requireExperiences;
        final avg = _avgRatings[p.uuid];
        if (avg == null) return !_expFilter.requireExperiences;
        return avg >= _expFilter.minAvgRating;
      }).toList();
    }

    // Distance filter (Haversine exact; bounding-box pre-filter is done in the DB).
    if (_expFilter.distanceEnabled && pos != null) {
      final maxM = _expFilter.maxDistanceKm * 1000;
      filtered = filtered
          .where(
            (p) =>
                GeoUtils.distanceMeters(pos.lat, pos.lng, p.lat, p.lng) <= maxM,
          )
          .toList();
    }

    return filtered;
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

  void _onMapTap(TapPosition _, LatLng _) {
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
              AppLocalizations.of(ctx)!.whichPlaceToOpen,
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

  Future<void> _onLongPress(TapPosition tap, LatLng latlng) =>
      handleMapLongPress(context, tap, latlng, onCreated: _loadPlaces);

  void _showPlaceSheet(SavedPlace place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaceDetailScreen(
          place: place,
          onUpdated: _loadPlaces,
          onDeleted: _loadPlaces,
        ),
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
    final l10n = AppLocalizations.of(context)!;
    return FocusDetector(
      onFocusGained: () {
        ForegroundServiceManager.addDataListener(_onServiceData);
        _loadPlaces().then((_) {
          if (mounted) {
            _loadTrackingPoints().then((_) {
              if (mounted) {
                setState(() {}); // Refresh to show tracking points if enabled.
              }
            });
          }
        });
      },
      onFocusLost: () =>
          ForegroundServiceManager.removeDataListener(_onServiceData),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.mapTitle),
          actions: [
            IconButton(
              icon: Badge(
                isLabelVisible:
                    _expFilter.isActive || _expFilter.distanceEnabled,
                child: const Icon(Icons.filter_list),
              ),
              tooltip: l10n.tooltipFilter,
              onPressed: () =>
                  setState(() => _filterPanelOpen = !_filterPanelOpen),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _showAddressSearch,
              tooltip: l10n.tooltipAddressSearch,
            ),
          ],
        ),
        body: Column(
          children: [
            if (_filterPanelOpen)
              ExperienceFilterPanel(
                filter: _expFilter,
                onChanged: (f) {
                  setState(() {
                    _expFilter = f;
                    _places = _applyFilter(_places);
                  });
                  final s = SettingsService.instance;
                  s.filterRequireExperiences = f.requireExperiences;
                  s.filterMinAvgRating = f.minAvgRating;
                  s.filterDistanceEnabled = f.distanceEnabled;
                  s.filterMaxDistanceKm = f.maxDistanceKm;
                  _loadPlaces();
                },
              ),
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
                      onSecondaryTap: _onLongPress,
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
          tooltip: l10n.toMyPosition,
          child: const Icon(Icons.my_location),
        ),
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
        return PlaceMapAddressSearch(
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
              title: Text(AppLocalizations.of(ctx)!.createPlaceHere),
              onTap: () {
                Navigator.pop(ctx);
                _onLongPress(const TapPosition(Offset.zero, Offset.zero), pos);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions),
              title: Text(AppLocalizations.of(ctx)!.routeInGoogleMaps),
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
        CircleLayer(circles: circles),
      ],
    );
  }
}
