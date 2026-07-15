import 'dart:math';

import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/place_group.dart';
import '../../../models/saved_place.dart';
import '../../../models/stay.dart';
import '../../../models/stay_activity.dart';
import '../../../models/stay_person.dart';
import '../../../services/database_service.dart';
import '../../../services/foreground_service_handler.dart';
import '../../../services/settings_service.dart';
import '../../../utils/place_creation_helper.dart';
import 'place_detail_screen.dart';
import '../stay/stay_card.dart';

class PlacesTimelineScreen extends StatefulWidget {
  const PlacesTimelineScreen({super.key});

  @override
  State<PlacesTimelineScreen> createState() => _PlacesTimelineScreenState();
}

class _PlacesTimelineScreenState extends State<PlacesTimelineScreen> {
  // ── Map / shared data (loaded in full) ───────────────────────────────────
  List<Stay> _stays = [];
  List<SavedPlace> _places = [];
  List<PlaceGroup> _groups = [];
  Map<String, int?> _lastVisitByPlace = {};

  // ── Besuche list (DB-paginated, accumulated) ─────────────────────────────
  List<Stay> _listStays = [];
  Map<String, List<StayPerson>> _listPersonsByStay = {};
  Map<String, List<StayActivity>> _listActivitiesByStay = {};
  bool _listHasMore = false;
  bool _listLoading = false;

  // ── Planer scheduler (DB-paginated, accumulated) ──────────────────────────
  List<({SavedPlace place, int daysRemaining})> _schedulerItems = [];
  bool _schedulerHasMore = false;
  bool _schedulerLoading = false;

  // Filter state
  DateTimeRange? _filterRange;
  bool _filterOwnDeviceOnly = true;

  // Search state
  bool _searchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Map
  final MapController _mapController = MapController();
  LatLng? _lastKnownPosition;

  // Pagination
  static const int _kChunkSize = 20;
  final ScrollController _staysScrollCtrl = ScrollController();
  final ScrollController _schedulerScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _staysScrollCtrl.addListener(_onStaysScroll);
    _schedulerScrollCtrl.addListener(_onSchedulerScroll);
    _load();
    _loadLastPosition();
  }

  void _onStaysScroll() {
    if (!_staysScrollCtrl.hasClients) return;
    final pos = _staysScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 &&
        _listHasMore &&
        !_listLoading) {
      _loadNextListChunk();
    }
  }

  void _onSchedulerScroll() {
    if (!_schedulerScrollCtrl.hasClients) return;
    final pos = _schedulerScrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 &&
        _schedulerHasMore &&
        !_schedulerLoading) {
      _loadNextSchedulerChunk();
    }
  }

  void _onServiceData(Object data) {
    _load(silent: true);
    _loadLastPosition();
  }

  @override
  void dispose() {
    ForegroundServiceManager.removeDataListener(_onServiceData);
    _staysScrollCtrl.dispose();
    _schedulerScrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLastPosition() async {
    final pts = await DatabaseService.instance.loadTrackingPointsSince(0);
    if (pts.isNotEmpty && mounted) {
      final last = pts.last;
      setState(() => _lastKnownPosition = LatLng(last.lat, last.lng));
    }
  }

  /// Loads all shared / map data, then resets and reloads both paginated lists.
  Future<void> _load({bool silent = false}) async {
    final results = await Future.wait([
      DatabaseService.instance.loadCompletedStays(),
      DatabaseService.instance.loadAllPlaces(),
      DatabaseService.instance.loadAllPlaceGroups(),
    ]);

    final stays = results[0] as List<Stay>;
    final places = results[1] as List<SavedPlace>;
    final groups = results[2] as List<PlaceGroup>;

    // last-visit timestamps for interval-enabled places (for map coloring)
    final intervalPlaces = places.where((p) => p.intervalEnabled);
    final lastVisits = <String, int?>{};
    for (final p in intervalPlaces) {
      lastVisits[p.uuid] = await DatabaseService.instance.lastVisitedAtForPlace(
        p.uuid,
      );
    }

    if (mounted) {
      setState(() {
        _stays = stays;
        _places = places;
        _groups = groups;
        _lastVisitByPlace = lastVisits;
      });
    }
    await Future.wait([
      _reloadList(silent: silent),
      _reloadScheduler(silent: silent),
    ]);
  }

  // ── Besuche list ─────────────────────────────────────────────────────────

  /// Resets the stay list and loads the first page from the DB.
  /// When [silent] is true the existing items remain visible and no spinner
  /// is shown — the data is replaced quietly once the first page arrives.
  Future<void> _reloadList({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _listStays = [];
        _listPersonsByStay = {};
        _listActivitiesByStay = {};
        _listHasMore = false;
        _listLoading = true;
      });
    }
    await _loadNextListChunk(silent: silent);
  }

  Future<void> _loadNextListChunk({bool silent = false}) async {
    if (!silent && _listLoading && _listStays.isNotEmpty) return;
    if (!mounted) return;
    if (!silent) setState(() => _listLoading = true);
    try {
      final offset = silent ? 0 : _listStays.length;
      final page = await DatabaseService.instance.loadCompletedStaysPaged(
        limit: _kChunkSize,
        offset: offset,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        fromMs: _filterRange?.start.millisecondsSinceEpoch,
        toMs: _filterRange?.end
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
        deviceId: _filterOwnDeviceOnly
            ? SettingsService.instance.deviceId
            : null,
      );

      // Load persons + activities for this page only.
      final personLists = await Future.wait(
        page.map((s) => DatabaseService.instance.loadPersonsForStay(s.uuid)),
      );
      final activityLists = await Future.wait(
        page.map((s) => DatabaseService.instance.loadActivitiesForStay(s.uuid)),
      );

      if (mounted) {
        setState(() {
          if (silent) {
            _listStays = page;
            _listPersonsByStay = {};
            _listActivitiesByStay = {};
          } else {
            _listStays = [..._listStays, ...page];
          }
          for (var i = 0; i < page.length; i++) {
            _listPersonsByStay[page[i].uuid] = personLists[i];
            _listActivitiesByStay[page[i].uuid] = activityLists[i];
          }
          _listHasMore = page.length == _kChunkSize;
          if (!silent) _listLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _listLoading = false);
    }
  }

  // ── Planer scheduler ──────────────────────────────────────────────────────

  /// When [silent] is true the existing items remain visible and no spinner
  /// is shown — the data is replaced quietly once the first page arrives.
  Future<void> _reloadScheduler({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _schedulerItems = [];
        _schedulerHasMore = false;
        _schedulerLoading = true;
      });
    }
    await _loadNextSchedulerChunk(silent: silent);
  }

  Future<void> _loadNextSchedulerChunk({bool silent = false}) async {
    if (!silent && _schedulerLoading && _schedulerItems.isNotEmpty) return;
    if (!mounted) return;
    if (!silent) setState(() => _schedulerLoading = true);
    try {
      final page = await DatabaseService.instance.loadSchedulerPlacesPaged(
        limit: _kChunkSize,
        offset: silent ? 0 : _schedulerItems.length,
      );
      if (mounted) {
        setState(() {
          _schedulerItems = silent ? page : [..._schedulerItems, ...page];
          _schedulerHasMore = page.length == _kChunkSize;
          if (!silent) _schedulerLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _schedulerLoading = false);
    }
  }

  // ── Map filtered stays (Dart-side, for map polyline) ──────────────────────

  List<Stay> get _filteredStays {
    final ownId = _filterOwnDeviceOnly
        ? SettingsService.instance.deviceId
        : null;
    return _stays.where((s) {
      if (_filterRange != null) {
        final dt = s.startDateTime;
        if (dt.isBefore(_filterRange!.start) || dt.isAfter(_filterRange!.end)) {
          return false;
        }
      }
      if (ownId != null && s.deviceId != ownId) return false;
      return true;
    }).toList();
  }

  SavedPlace? _placeForStay(Stay s) {
    if (s.placeUuid == null) return null;
    return _places.where((p) => p.uuid == s.placeUuid).firstOrNull;
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _filterRange,
    );
    if (range != null && mounted) {
      setState(() => _filterRange = range);
      _reloadList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusDetector(
      onFocusGained: () {
        ForegroundServiceManager.addDataListener(_onServiceData);
        final silent = _listStays.isNotEmpty || _schedulerItems.isNotEmpty;
        _load(silent: silent).then((_) {
          if (mounted) {
            setState(() {
              _loadLastPosition();
            });
          }
        });
        setState(() {});
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
                    hintText: AppLocalizations.of(context)!.searchStaysHint,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    _reloadList();
                  },
                )
              : Text(AppLocalizations.of(context)!.visitsTitle),
          actions: [
            if (_searchActive)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: AppLocalizations.of(context)!.closeSearch,
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
              // Filter by date
              IconButton(
                icon: Badge(
                  isLabelVisible: _filterRange != null,
                  child: const Icon(Icons.date_range),
                ),
                onPressed: _pickDateRange,
                tooltip: AppLocalizations.of(context)!.filterByDate,
              ),
              // Filter by own device ID
              IconButton(
                icon: Badge(
                  isLabelVisible: _filterOwnDeviceOnly,
                  child: const Icon(Icons.smartphone),
                ),
                onPressed: () {
                  setState(() => _filterOwnDeviceOnly = !_filterOwnDeviceOnly);
                  _reloadList();
                },
                tooltip: AppLocalizations.of(context)!.deviceIdStayFilter,
              ),
              // Clear date filter
              if (_filterRange != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => _filterRange = null);
                    _reloadList();
                  },
                  tooltip: AppLocalizations.of(context)!.resetFilter,
                ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: AppLocalizations.of(context)!.search,
                onPressed: () => setState(() => _searchActive = true),
              ),
            ],
          ],
        ),
        body: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(
                    icon: const Icon(Icons.list),
                    text: AppLocalizations.of(context)!.tabList,
                  ),
                  Tab(
                    icon: const Icon(Icons.map),
                    text: AppLocalizations.of(context)!.tabJourney,
                  ),
                  Tab(
                    icon: const Icon(Icons.schedule),
                    text: AppLocalizations.of(context)!.tabPlanner,
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [_buildList(), _buildMap(), _buildScheduler()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final l10n = AppLocalizations.of(context)!;
    if (!_listLoading && _listStays.isEmpty) {
      return Center(
        child: Text(l10n.noStaysFound, textAlign: TextAlign.center),
      );
    }

    // Group accumulated stays by date.
    final grouped = <String, List<Stay>>{};
    for (final s in _listStays) {
      final dt = s.startDateTime;
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(s);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    // Flat list: date headers (String) + stays (Stay).
    final List<Object> items = [];
    for (final date in dates) {
      items.add(date);
      items.addAll(grouped[date]!);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _staysScrollCtrl,
        itemCount: items.length + (_listHasMore || _listLoading ? 1 : 0),
        itemBuilder: (ctx, index) {
          if (index == items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = items[index];
          if (item is String) {
            final parts = item.split('-');
            final dt = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}',
                style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                  color: Theme.of(ctx).colorScheme.primary,
                ),
              ),
            );
          }
          final stay = item as Stay;
          return StayCard(
            stay: stay,
            place: _placeForStay(stay),
            persons: _listPersonsByStay[stay.uuid] ?? [],
            activities: _listActivitiesByStay[stay.uuid] ?? [],
            onUpdated: _load,
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    final historyDays = SettingsService.instance.timelineHistoryDays;
    final colorRange = SettingsService.instance.schedulerColorRange;
    final cutoff = DateTime.now().subtract(Duration(days: historyDays));

    // Polyline: stays with known place coords, sorted oldest → newest
    final stayEntries =
        _filteredStays
            .where((s) => s.startDateTime.isAfter(cutoff))
            .map((s) => (stay: s, place: _placeForStay(s)))
            .where((e) => e.place != null)
            .toList()
          ..sort((a, b) => a.stay.startTime.compareTo(b.stay.startTime));

    final stayPoints = stayEntries
        .map((e) => LatLng(e.place!.lat, e.place!.lng))
        .toList();

    List<Color>? gradientColors;
    if (stayPoints.length >= 2) {
      final n = stayPoints.length;
      gradientColors = List.generate(n, (i) {
        final opacity = i / (n - 1);
        return Colors.teal.withValues(alpha: max(opacity, 0.5));
      });
    }

    // Build markers for all places with their urgency colors
    final markers = _places.map((p) {
      Color markerColor;
      if (!p.intervalEnabled) {
        markerColor = Colors.grey;
      } else {
        final lastMs = _lastVisitByPlace[p.uuid];
        int daysRemaining;
        if (lastMs == null) {
          daysRemaining = 0;
        } else {
          final daysSince = DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(lastMs))
              .inDays;
          daysRemaining = (p.intervalDays ?? 0) - daysSince;
        }
        markerColor = _urgencyColor(daysRemaining, colorRange);
      }
      return Marker(
        point: LatLng(p.lat, p.lng),
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlaceDetailScreen(
                place: p,
                onUpdated: _load,
                onDeleted: _load,
              ),
            ),
          ),
          child: Icon(Icons.location_pin, color: markerColor, size: 36),
        ),
      );
    }).toList();

    final center =
        _lastKnownPosition ??
        (_places.isNotEmpty
            ? LatLng(_places.first.lat, _places.first.lng)
            : const LatLng(48.1351, 11.5820));

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12,
            onLongPress: _onMapLongPress,
            onSecondaryTap: _onMapLongPress,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'de.chaostours.chaos_tours_ai',
            ),
            if (stayPoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: stayPoints,
                    strokeWidth: 3.0,
                    gradientColors: gradientColors,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.small(
            heroTag: 'timeline_location',
            onPressed: () {
              final pos = _lastKnownPosition;
              if (pos != null) _mapController.move(pos, 14);
            },
            tooltip: AppLocalizations.of(context)!.toLastPosition,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  /// Returns a color on the green-yellow-red gradient based on [daysRemaining]
  /// and [colorRange]. colorRange days = green, 0 = yellow, -colorRange = red.
  Color _urgencyColor(int daysRemaining, int colorRange) {
    if (colorRange <= 0) return Colors.yellow;
    if (daysRemaining >= colorRange) return Colors.green;
    if (daysRemaining <= -colorRange) return Colors.red;
    if (daysRemaining >= 0) {
      // green → yellow
      final t = 1.0 - daysRemaining / colorRange;
      return Color.lerp(Colors.green, Colors.yellow, t)!;
    } else {
      // yellow → red
      final t = (-daysRemaining) / colorRange;
      return Color.lerp(Colors.yellow, Colors.red, t)!;
    }
  }

  Widget _buildScheduler() {
    final colorRange = SettingsService.instance.schedulerColorRange;

    if (!_schedulerLoading && _schedulerItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context)!.noSchedulerPlaces,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _schedulerScrollCtrl,
        itemCount:
            _schedulerItems.length +
            (_schedulerHasMore || _schedulerLoading ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == _schedulerItems.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final entry = _schedulerItems[i];
          final place = entry.place;
          final days = entry.daysRemaining;
          final color = _urgencyColor(days, colorRange);
          final group = place.groupUuid != null
              ? _groups.where((g) => g.uuid == place.groupUuid).firstOrNull
              : null;

          String daysLabel;
          final l10n = AppLocalizations.of(ctx)!;
          if (days == 0) {
            daysLabel = l10n.schedulerToday;
          } else if (days > 0) {
            daysLabel = days == 1
                ? l10n.schedulerInDay(days)
                : l10n.schedulerInDays(days);
          } else {
            daysLabel = (-days) == 1
                ? l10n.schedulerOverdueDay(-days)
                : l10n.schedulerOverdueDays(-days);
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlaceDetailScreen(
                    place: place,
                    onUpdated: _load,
                    onDeleted: _load,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            days.abs().toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              shadows: [
                                Shadow(color: Colors.black26, blurRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            daysLabel,
                            style: TextStyle(
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black87
                                  : color,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          if (group != null)
                            Text(
                              group.name,
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      ctx,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          if (place.intervalDays != null)
                            Text(
                              l10n.intervalDays(place.intervalDays!),
                              style: Theme.of(ctx).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      ctx,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    Icon(place.placeType.icon, color: place.placeType.dotColor),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onMapLongPress(TapPosition tap, LatLng latlng) =>
      handleMapLongPress(context, tap, latlng, onCreated: _load);
}
