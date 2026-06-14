import 'dart:math';

import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/place_group.dart';
import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../models/stay_activity.dart';
import '../../models/stay_person.dart';
import '../../services/database_service.dart';
import '../../services/foreground_service_handler.dart';
import '../../services/settings_service.dart';
import '../../utils/place_creation_helper.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/stay_card.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Stay> _stays = [];
  List<SavedPlace> _places = [];
  List<PlaceGroup> _groups = [];
  Map<String, List<StayPerson>> _personsByStay = {};
  Map<String, List<StayActivity>> _activitiesByStay = {};
  Map<String, int?> _lastVisitByPlace = {}; // placeUuid -> lastVisit ms

  // Filter state
  DateTimeRange? _filterRange;
  String? _filterPlaceUuid;

  // Search state
  bool _searchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Map
  final MapController _mapController = MapController();
  LatLng? _lastKnownPosition;

  @override
  void initState() {
    super.initState();
    _load();
    _loadLastPosition();
  }

  void _onServiceData(Object data) {
    _load();
    _loadLastPosition();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLastPosition() async {
    // Use most recent tracking point as last known position
    final pts = await DatabaseService.instance.loadTrackingPointsSince(0);
    if (pts.isNotEmpty && mounted) {
      final last = pts.last;
      setState(() => _lastKnownPosition = LatLng(last.lat, last.lng));
    }
  }

  Future<void> _load() async {
    final results = await Future.wait([
      DatabaseService.instance.loadCompletedStays(),
      DatabaseService.instance.loadAllPlaces(),
      DatabaseService.instance.loadAllPlaceGroups(),
    ]);

    final stays = results[0] as List<Stay>;
    final places = results[1] as List<SavedPlace>;
    final groups = results[2] as List<PlaceGroup>;

    // Load relations for all stays
    final personLists = await Future.wait(
      stays.map((s) => DatabaseService.instance.loadPersonsForStay(s.uuid)),
    );
    final activityLists = await Future.wait(
      stays.map((s) => DatabaseService.instance.loadActivitiesForStay(s.uuid)),
    );

    // Load last-visit timestamps for interval-enabled places
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
        _personsByStay = {
          for (var i = 0; i < stays.length; i++) stays[i].uuid: personLists[i],
        };
        _activitiesByStay = {
          for (var i = 0; i < stays.length; i++)
            stays[i].uuid: activityLists[i],
        };
        _lastVisitByPlace = lastVisits;
      });
    }
  }

  List<Stay> get _filteredStays {
    return _stays.where((s) {
      if (_filterRange != null) {
        final dt = s.startDateTime;
        if (dt.isBefore(_filterRange!.start) || dt.isAfter(_filterRange!.end)) {
          return false;
        }
      }
      if (_filterPlaceUuid != null && s.placeUuid != _filterPlaceUuid) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final place = _placeForStay(s);
        final placeName = place?.name.toLowerCase() ?? '';
        final address = s.address?.toLowerCase() ?? '';
        final notes = s.notes.toLowerCase();
        final persons = (_personsByStay[s.uuid] ?? [])
            .map((p) => p.name.toLowerCase())
            .join(' ');
        final activities = (_activitiesByStay[s.uuid] ?? [])
            .map((a) => a.description.toLowerCase())
            .join(' ');
        if (!placeName.contains(q) &&
            !address.contains(q) &&
            !notes.contains(q) &&
            !persons.contains(q) &&
            !activities.contains(q)) {
          return false;
        }
      }
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusDetector(
      onFocusGained: () {
        ForegroundServiceManager.addDataListener(_onServiceData);
        _load().then((_) {
          // After loading, also refresh the last known position in case it changed.
          if (mounted) {
            setState(() {
              _loadLastPosition();
            });
          }
        });
        setState(() {}); // Refresh to show tracking points if enabled.
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
                  onChanged: (v) => setState(() => _searchQuery = v),
                )
              : Text(AppLocalizations.of(context)!.visitsTitle),
          actions: [
            if (_searchActive)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: AppLocalizations.of(context)!.closeSearch,
                onPressed: () => setState(() {
                  _searchActive = false;
                  _searchQuery = '';
                  _searchCtrl.clear();
                }),
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
              // Filter by place
              IconButton(
                icon: Badge(
                  isLabelVisible: _filterPlaceUuid != null,
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: _showPlaceFilterSheet,
                tooltip: AppLocalizations.of(context)!.filterByPlace,
              ),
              // Clear filters
              if (_filterRange != null || _filterPlaceUuid != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _filterRange = null;
                    _filterPlaceUuid = null;
                  }),
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
    final filtered = _filteredStays;
    if (filtered.isEmpty) {
      return Center(
        child: Text(l10n.noStaysFound, textAlign: TextAlign.center),
      );
    }

    // Group by date
    final grouped = <String, List<Stay>>{};
    for (final s in filtered) {
      final dt = s.startDateTime;
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(s);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: dates.fold<int>(
          0,
          (acc, d) => acc + 1 + (grouped[d]?.length ?? 0),
        ),
        itemBuilder: (ctx, index) {
          int offset = 0;
          for (final date in dates) {
            if (index == offset) {
              // Date header
              final parts = date.split('-');
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
            offset++;
            final staysForDate = grouped[date]!;
            if (index < offset + staysForDate.length) {
              final stay = staysForDate[index - offset];
              return StayCard(
                stay: stay,
                place: _placeForStay(stay),
                persons: _personsByStay[stay.uuid] ?? [],
                activities: _activitiesByStay[stay.uuid] ?? [],
                onUpdated: _load,
              );
            }
            offset += staysForDate.length;
          }
          return const SizedBox.shrink();
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
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) =>
                PlaceBottomSheet(place: p, onUpdated: _load, onDeleted: _load),
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
    final settings = SettingsService.instance;
    final colorRange = settings.schedulerColorRange;
    final groupFilter = settings.schedulerGroupUuidList;

    // Filter to interval-enabled places
    var schedulerPlaces = _places.where((p) => p.intervalEnabled).toList();

    // Apply group filter
    if (groupFilter.isNotEmpty) {
      schedulerPlaces = schedulerPlaces
          .where(
            (p) => p.groupUuid != null && groupFilter.contains(p.groupUuid),
          )
          .toList();
    }

    if (schedulerPlaces.isEmpty) {
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

    // Calculate days-remaining for each place
    final now = DateTime.now();
    final entries = schedulerPlaces.map((p) {
      final lastMs = _lastVisitByPlace[p.uuid];
      int daysRemaining;
      if (lastMs == null) {
        // Never visited → due today
        daysRemaining = 0;
      } else {
        final daysSince = now
            .difference(DateTime.fromMillisecondsSinceEpoch(lastMs))
            .inDays;
        final interval = p.intervalDays ?? 0;
        daysRemaining = interval - daysSince;
      }
      return (place: p, daysRemaining: daysRemaining);
    }).toList()..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (ctx, i) {
          final entry = entries[i];
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
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => PlaceBottomSheet(
                  place: place,
                  onUpdated: _load,
                  onDeleted: _load,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Urgency indicator
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
      createPlaceFromLongPress(context, tap, latlng, onCreated: _load);

  void _showPlaceFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.clear),
            title: Text(AppLocalizations.of(ctx)!.allPlaces),
            selected: _filterPlaceUuid == null,
            onTap: () {
              setState(() => _filterPlaceUuid = null);
              Navigator.pop(ctx);
            },
          ),
          ..._places.map(
            (p) => ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(p.name),
              selected: _filterPlaceUuid == p.uuid,
              onTap: () {
                setState(() => _filterPlaceUuid = p.uuid);
                Navigator.pop(ctx);
              },
            ),
          ),
        ],
      ),
    );
  }
}
