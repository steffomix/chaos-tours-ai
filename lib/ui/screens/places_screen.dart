import 'dart:math';

import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:latlong2/latlong.dart';

import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';
import '../../services/foreground_service_handler.dart';
import '../../services/settings_service.dart';
import '../../services/location_service.dart';
import '../../utils/geo_utils.dart';
import '../../utils/place_creation_helper.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/experience_filter_panel.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  // ── Map data (loaded in full) ────────────────────────────────────────────
  List<SavedPlace> _mapPlaces = [];

  // ── List data (DB-paginated, accumulated) ────────────────────────────────
  List<({SavedPlace place, double? distance})> _listItems = [];
  Map<String, int> _visitCounts = {};
  Map<String, Stay?> _lastStay = {};
  bool _listHasMore = false;
  bool _listLoading = false;

  // Search
  bool _searchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Filter
  bool _intervalOnly = false;
  bool _filterPanelOpen = false;
  ExperienceFilterState _expFilter = const ExperienceFilterState();

  // Map
  final MapController _mapController = MapController();

  // Distance
  ({double lat, double lng})? _currentPos;

  // Pagination
  static const int _kChunkSize = 20;
  final ScrollController _placesScrollCtrl = ScrollController();

  bool get _isDistanceMode => _expFilter.distanceEnabled && _currentPos != null;

  @override
  void initState() {
    super.initState();
    _placesScrollCtrl.addListener(_onPlacesScroll);
    final s = SettingsService.instance;
    _expFilter = ExperienceFilterState(
      requireExperiences: s.filterRequireExperiences,
      minAvgRating: s.filterMinAvgRating,
      useMedian: s.filterUseMedian,
      distanceEnabled: s.filterDistanceEnabled,
      maxDistanceKm: s.filterMaxDistanceKm,
    );
    _loadCurrentPosition().then((_) => _loadPlaces());
  }

  void _onPlacesScroll() {
    if (!_placesScrollCtrl.hasClients) return;
    final pos = _placesScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 &&
        _listHasMore &&
        !_listLoading) {
      _loadNextListChunk();
    }
  }

  @override
  void dispose() {
    ForegroundServiceManager.removeDataListener(_onServiceData);
    _placesScrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onServiceData(Object data) {
    _loadCurrentPosition().then((_) => _loadPlaces(silent: true));
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() => _currentPos = (lat: pos.latitude, lng: pos.longitude));
      }
    } catch (_) {}
  }

  /// Reload both map data and list (first page).
  Future<void> _loadPlaces({bool silent = false}) async {
    await Future.wait([_loadMapData(), _reloadList(silent: silent)]);
  }

  /// Loads all places for the map tab (bounding-box limited in distance mode).
  Future<void> _loadMapData() async {
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
    if (mounted) {
      setState(() {
        _mapPlaces = places;
      });
    }
  }

  /// Resets the list and loads the first chunk from the DB.
  /// When [silent] is true the existing items remain visible and no spinner
  /// is shown — the data is replaced quietly once the first page arrives.
  Future<void> _reloadList({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _listItems = [];
        _visitCounts = {};
        _lastStay = {};
        _listHasMore = false;
        _listLoading = true;
      });
    }
    await _loadNextListChunk(silent: silent);
  }

  /// Loads the next page and appends it to [_listItems].
  /// When [silent] is true, offset is always 0 and the result replaces
  /// the existing list without touching [_listLoading].
  Future<void> _loadNextListChunk({bool silent = false}) async {
    if (!silent && _listLoading && _listItems.isNotEmpty) return;
    if (!mounted) return;
    if (!silent) setState(() => _listLoading = true);

    try {
      if (_isDistanceMode) {
        // Distance mode: use bounding-box prefiltered _mapPlaces, sort in Dart.
        // Whole set is already bounded by the bounding box — show everything.
        final pos = _currentPos!;
        final maxM = _expFilter.maxDistanceKm * 1000;
        final groupFilter = SettingsService.instance.schedulerGroupUuidList;
        var list = _mapPlaces;
        if (groupFilter.isNotEmpty) {
          list = list
              .where(
                (p) => p.groupUuid != null && groupFilter.contains(p.groupUuid),
              )
              .toList();
        }
        if (_intervalOnly) list = list.where((p) => p.intervalEnabled).toList();
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          list = list.where((p) {
            if (p.name.toLowerCase().contains(q)) return true;
            if (p.notes.toLowerCase().contains(q)) return true;
            if (p.placeType.label.toLowerCase().contains(q)) return true;
            return false;
          }).toList();
        }
        if (_expFilter.isActive) {
          list = list.where((p) {
            final rating = _expFilter.useMedian
                ? p.experienceRatingMedian
                : p.experienceRatingAverage;
            if (rating == null) return !_expFilter.requireExperiences;
            return rating >= _expFilter.minAvgRating;
          }).toList();
        }
        var result =
            list
                .map((p) {
                  final d = GeoUtils.distanceMeters(
                    pos.lat,
                    pos.lng,
                    p.lat,
                    p.lng,
                  );
                  return (place: p, distance: d);
                })
                .where((e) => e.distance <= maxM)
                .toList()
              ..sort((a, b) {
                final distCmp = a.distance.compareTo(b.distance);
                if (distCmp != 0) return distCmp;
                final rA =
                    (_expFilter.useMedian
                        ? a.place.experienceRatingMedian
                        : a.place.experienceRatingAverage) ??
                    0.0;
                final rB =
                    (_expFilter.useMedian
                        ? b.place.experienceRatingMedian
                        : b.place.experienceRatingAverage) ??
                    0.0;
                return rB.compareTo(rA);
              });

        // Load visit metadata for newly-visible items.
        final newPlaces = result.map((e) => e.place).toList();
        final counts = <String, int>{..._visitCounts};
        final stays = <String, Stay?>{..._lastStay};
        for (final p in newPlaces) {
          if (!counts.containsKey(p.uuid)) {
            counts[p.uuid] = await DatabaseService.instance.visitCountForPlace(
              p.uuid,
            );
            stays[p.uuid] = await DatabaseService.instance
                .lastCompletedStayForPlace(p.uuid);
          }
        }
        if (mounted) {
          setState(() {
            _listItems = result;
            _visitCounts = counts;
            _lastStay = stays;
            _listHasMore = false;
            if (!silent) _listLoading = false;
          });
        }
      } else {
        // Normal mode: proper DB LIMIT/OFFSET pagination.
        final offset = silent ? 0 : _listItems.length;
        final q = _searchQuery.isNotEmpty ? _searchQuery.toLowerCase() : null;
        final placeTypeIndices = q != null
            ? PlaceType.values
                  .where((t) => t.label.toLowerCase().contains(q))
                  .map((t) => t.index)
                  .toList()
            : <int>[];

        final page = await DatabaseService.instance.loadPlacesPaged(
          limit: _kChunkSize,
          offset: offset,
          search: q,
          intervalOnly: _intervalOnly,
          groupFilter: SettingsService.instance.schedulerGroupUuidList,
          requireExperiences: _expFilter.requireExperiences,
          minAvgRating: _expFilter.isActive ? _expFilter.minAvgRating : null,
          useMedian: _expFilter.useMedian,
          placeTypeIndices: placeTypeIndices,
        );

        // Load visit metadata for this page.
        final counts = <String, int>{..._visitCounts};
        final stays = <String, Stay?>{..._lastStay};
        for (final p in page) {
          counts[p.uuid] = await DatabaseService.instance.visitCountForPlace(
            p.uuid,
          );
          stays[p.uuid] = await DatabaseService.instance
              .lastCompletedStayForPlace(p.uuid);
        }

        if (mounted) {
          setState(() {
            _listItems = [
              if (!silent) ..._listItems,
              ...page.map((p) => (place: p, distance: null)),
            ];
            _visitCounts = counts;
            _lastStay = stays;
            _listHasMore = page.length == _kChunkSize;
            if (!silent) _listLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDuration(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}min';
    return '${d.inMinutes}min';
  }

  String _fmtDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _openSheet(SavedPlace place) {
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

  bool get _filterActive =>
      _intervalOnly || _expFilter.isActive || _expFilter.distanceEnabled;

  Color _ratingColor(double? rating) {
    if (rating == null) return Colors.grey;
    if (rating >= 9) return Colors.green;
    if (rating <= -9) return Colors.red;
    if (rating >= 0) {
      final t = 1.0 - rating / 9.0;
      return Color.lerp(Colors.green, Colors.yellow, t)!;
    } else {
      final t = (-rating) / 9.0;
      return Color.lerp(Colors.yellow, Colors.red, t)!;
    }
  }

  Widget _buildList() {
    final l10n = AppLocalizations.of(context)!;
    if (!_listLoading && _listItems.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty || _expFilter.isActive
              ? l10n.noPlacesFound
              : l10n.noPlacesSaved,
          textAlign: TextAlign.center,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPlaces,
      child: ListView.builder(
        controller: _placesScrollCtrl,
        itemCount: _listItems.length + (_listHasMore || _listLoading ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _listItems.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _listItems[i];
          final place = item.place;
          return _PlaceCard(
            place: place,
            count: _visitCounts[place.uuid] ?? 0,
            lastStay: _lastStay[place.uuid],
            distance: item.distance,
            avgRating: _expFilter.useMedian
                ? place.experienceRatingMedian
                : place.experienceRatingAverage,
            fmtDate: _fmtDate,
            fmtTime: _fmtTime,
            fmtDuration: _fmtDuration,
            fmtDistance: _fmtDistance,
            onTap: () => _openSheet(place),
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    final l10n = AppLocalizations.of(context)!;
    // Map always shows the full (map) dataset with Dart-side filtering.
    var list = _mapPlaces;
    final groupFilter = SettingsService.instance.schedulerGroupUuidList;
    if (groupFilter.isNotEmpty) {
      list = list
          .where(
            (p) => p.groupUuid != null && groupFilter.contains(p.groupUuid),
          )
          .toList();
    }
    if (_intervalOnly) list = list.where((p) => p.intervalEnabled).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        if (p.name.toLowerCase().contains(q)) return true;
        if (p.notes.toLowerCase().contains(q)) return true;
        if (p.placeType.label.toLowerCase().contains(q)) return true;
        return false;
      }).toList();
    }
    final places = list;
    final markers = places.map((p) {
      final color = _ratingColor(
        _expFilter.useMedian
            ? p.experienceRatingMedian
            : p.experienceRatingAverage,
      );
      return Marker(
        point: LatLng(p.lat, p.lng),
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _openSheet(p),
          child: Icon(Icons.location_pin, color: color, size: 36),
        ),
      );
    }).toList();

    final center = _currentPos != null
        ? LatLng(_currentPos!.lat, _currentPos!.lng)
        : (places.isNotEmpty
              ? LatLng(places.first.lat, places.first.lng)
              : const LatLng(48.1351, 11.5820));

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12,
            onLongPress: (tap, latlng) => createPlaceFromLongPress(
              context,
              tap,
              latlng,
              onCreated: _loadPlaces,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.chaostours.chaos_tours_ai',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'places_location',
            onPressed: () {
              final pos = _currentPos;
              if (pos != null) {
                _mapController.move(LatLng(pos.lat, pos.lng), 14);
              }
            },
            tooltip: l10n.toCurrentPosition,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FocusDetector(
      onFocusGained: () {
        ForegroundServiceManager.addDataListener(_onServiceData);
        final silent = _listItems.isNotEmpty;
        _loadPlaces(silent: silent).then((_) {
          if (mounted) setState(() {});
        });
      },
      onFocusLost: () =>
          ForegroundServiceManager.removeDataListener(_onServiceData),
      child: Scaffold(
        appBar: AppBar(
          title: _searchActive
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.searchPlaces,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() {
                    _searchQuery = v;
                    _reloadList();
                  }),
                )
              : Text(l10n.placesTitle),
          actions: [
            if (_searchActive)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.closeSearch,
                onPressed: () {
                  setState(() {
                    _searchActive = false;
                    _searchQuery = '';
                    _searchCtrl.clear();
                  });
                  _reloadList();
                },
              )
            else ...[
              IconButton(
                icon: Badge(
                  isLabelVisible: _intervalOnly,
                  child: const Icon(Icons.schedule),
                ),
                tooltip: _intervalOnly
                    ? l10n.showAllPlaces
                    : l10n.showIntervalOnly,
                onPressed: () {
                  setState(() => _intervalOnly = !_intervalOnly);
                  _reloadList();
                },
              ),
              IconButton(
                icon: Badge(
                  isLabelVisible: _filterActive,
                  child: const Icon(Icons.filter_list),
                ),
                tooltip: l10n.tooltipFilter,
                onPressed: () =>
                    setState(() => _filterPanelOpen = !_filterPanelOpen),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: l10n.search,
                onPressed: () => setState(() => _searchActive = true),
              ),
            ],
          ],
        ),
        body: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              if (_filterPanelOpen)
                ExperienceFilterPanel(
                  filter: _expFilter,
                  onChanged: (f) {
                    setState(() => _expFilter = f);
                    final s = SettingsService.instance;
                    s.filterRequireExperiences = f.requireExperiences;
                    s.filterMinAvgRating = f.minAvgRating;
                    s.filterUseMedian = f.useMedian;
                    s.filterDistanceEnabled = f.distanceEnabled;
                    s.filterMaxDistanceKm = f.maxDistanceKm;
                    _loadPlaces();
                  },
                ),
              TabBar(
                tabs: [
                  Tab(icon: const Icon(Icons.list), text: l10n.tabPlaces),
                  const Tab(icon: Icon(Icons.map), text: 'Survive'),
                ],
              ),
              Expanded(
                child: TabBarView(children: [_buildList(), _buildMap()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final SavedPlace place;
  final int count;
  final Stay? lastStay;
  final double? distance;
  final double? avgRating;
  final String Function(int ms) fmtDate;
  final String Function(DateTime dt) fmtTime;
  final String Function(Duration d) fmtDuration;
  final String Function(double m) fmtDistance;
  final VoidCallback onTap;

  const _PlaceCard({
    required this.place,
    required this.count,
    required this.lastStay,
    required this.fmtDate,
    required this.fmtTime,
    required this.fmtDuration,
    required this.fmtDistance,
    required this.onTap,
    this.distance,
    this.avgRating,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    place.placeType.icon,
                    color: place.placeType.dotColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      place.name,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (distance != null)
                    Text(
                      fmtDistance(distance!),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (avgRating != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.star, size: 14, color: Colors.amber),
                    Text(
                      avgRating!.toStringAsFixed(1),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                count == 0
                    ? l10n.notVisitedYet
                    : (count == 1
                          ? l10n.visitCount(count)
                          : l10n.visitCountPlural(count)),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (lastStay != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${l10n.lastVisit(fmtDate(lastStay!.startTime), fmtTime(lastStay!.startDateTime))}'
                  '${lastStay!.endDateTime != null ? ' – ${fmtTime(lastStay!.endDateTime!)}' : ''}'
                  '${lastStay!.endDateTime != null ? '  (${fmtDuration(lastStay!.duration)})' : ''}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (place.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  place.notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
