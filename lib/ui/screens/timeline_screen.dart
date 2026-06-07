import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/place_group.dart';
import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../models/stay_activity.dart';
import '../../models/stay_person.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/stay_card.dart';
import '../widgets/stay_detail_sheet.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Stay> _stays = [];
  List<SavedPlace> _places = [];
  List<PlaceGroup> _groups = [];
  Map<int, List<StayPerson>> _personsByStay = {};
  Map<int, List<StayActivity>> _activitiesByStay = {};
  Map<int, int?> _lastVisitByPlace = {}; // placeId -> lastVisit ms
  bool _loading = true;

  // Filter state
  DateTimeRange? _filterRange;
  int? _filterPlaceId;

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
    widget.refreshNotifier?.addListener(_load);
    _load();
    _loadLastPosition();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_load);
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
    if (mounted) setState(() => _loading = true);

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
      stays.map((s) => DatabaseService.instance.loadPersonsForStay(s.id!)),
    );
    final activityLists = await Future.wait(
      stays.map((s) => DatabaseService.instance.loadActivitiesForStay(s.id!)),
    );

    // Load last-visit timestamps for interval-enabled places
    final intervalPlaces = places.where(
      (p) => p.intervalEnabled && p.id != null,
    );
    final lastVisits = <int, int?>{};
    for (final p in intervalPlaces) {
      lastVisits[p.id!] = await DatabaseService.instance.lastVisitedAtForPlace(
        p.id!,
      );
    }

    if (mounted) {
      setState(() {
        _stays = stays;
        _places = places;
        _groups = groups;
        _personsByStay = {
          for (var i = 0; i < stays.length; i++) stays[i].id!: personLists[i],
        };
        _activitiesByStay = {
          for (var i = 0; i < stays.length; i++) stays[i].id!: activityLists[i],
        };
        _lastVisitByPlace = lastVisits;
        _loading = false;
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
      if (_filterPlaceId != null && s.placeId != _filterPlaceId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final place = _placeForStay(s);
        final placeName = place?.name.toLowerCase() ?? '';
        final address = s.address?.toLowerCase() ?? '';
        final notes = s.notes.toLowerCase();
        final persons = (_personsByStay[s.id] ?? [])
            .map((p) => p.name.toLowerCase())
            .join(' ');
        final activities = (_activitiesByStay[s.id] ?? [])
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
    if (s.placeId == null) return null;
    return _places.where((p) => p.id == s.placeId).firstOrNull;
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
    return Scaffold(
      appBar: AppBar(
        title: _searchActive
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Aufenthalte durchsuchen…',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('Zeitachse'),
        actions: [
          if (_searchActive)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Suche schließen',
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
              tooltip: 'Datumsbereich filtern',
            ),
            // Filter by place
            IconButton(
              icon: Badge(
                isLabelVisible: _filterPlaceId != null,
                child: const Icon(Icons.filter_list),
              ),
              onPressed: _showPlaceFilterSheet,
              tooltip: 'Nach Ort filtern',
            ),
            // Clear filters
            if (_filterRange != null || _filterPlaceId != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                  _filterRange = null;
                  _filterPlaceId = null;
                }),
                tooltip: 'Filter zurücksetzen',
              ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Suchen',
              onPressed: () => setState(() => _searchActive = true),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.list), text: 'Liste'),
                      Tab(icon: Icon(Icons.map), text: 'Karte'),
                      Tab(icon: Icon(Icons.schedule), text: 'Planer'),
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
    );
  }

  Widget _buildList() {
    final filtered = _filteredStays;
    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'Keine abgeschlossenen Aufenthalte gefunden.\nTracking einschalten um Aufenthalte aufzuzeichnen.',
          textAlign: TextAlign.center,
        ),
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
                persons: _personsByStay[stay.id] ?? [],
                activities: _activitiesByStay[stay.id] ?? [],
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
    final cutoff = DateTime.now().subtract(Duration(days: historyDays));

    final filtered = _filteredStays
        .where((s) => s.startDateTime.isAfter(cutoff))
        .toList();

    final staysWithCoords = filtered
        .map((s) => (stay: s, place: _placeForStay(s)))
        .where((e) => e.place != null || e.stay.address != null)
        .toList();

    // Build markers for stays that have a known place
    final markers = staysWithCoords.where((e) => e.place != null).map((e) {
      final p = e.place!;
      return Marker(
        point: LatLng(p.lat, p.lng),
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => StayDetailSheet(stay: e.stay, onUpdated: _load),
          ),
          child: const Icon(Icons.location_pin, color: Colors.teal, size: 36),
        ),
      );
    }).toList();

    // Build journey polyline: stays with coordinates sorted oldest → newest
    final stayEntries = staysWithCoords.where((e) => e.place != null).toList()
      ..sort((a, b) => a.stay.startTime.compareTo(b.stay.startTime));

    final stayPoints = stayEntries
        .map((e) => LatLng(e.place!.lat, e.place!.lng))
        .toList();

    // Gradient: transparent (oldest/past) → opaque teal (newest/present)
    List<Color>? gradientColors;
    if (stayPoints.length >= 2) {
      final n = stayPoints.length;
      gradientColors = List.generate(n, (i) {
        final opacity = i / (n - 1); // 0.0 … 1.0
        return Colors.teal.withValues(alpha: max(opacity, 0.5));
      }).reversed.toList(); // Newest = most opaque at the end of the list
    }

    final center =
        _lastKnownPosition ??
        (markers.isNotEmpty
            ? LatLng(
                staysWithCoords.first.place!.lat,
                staysWithCoords.first.place!.lng,
              )
            : const LatLng(48.1351, 11.5820));

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: center, initialZoom: 12),
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
            tooltip: 'Zur letzten Position',
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
    final groupFilter = settings.schedulerGroupIdList;

    // Filter to interval-enabled places
    var schedulerPlaces = _places.where((p) => p.intervalEnabled).toList();

    // Apply group filter
    if (groupFilter.isNotEmpty) {
      schedulerPlaces = schedulerPlaces
          .where((p) => p.groupId != null && groupFilter.contains(p.groupId))
          .toList();
    }

    if (schedulerPlaces.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Keine Planer-Orte vorhanden.\n\n'
            'Aktiviere das Besuchs-Intervall für Orte in den Ortseinstellungen.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Calculate days-remaining for each place
    final now = DateTime.now();
    final entries = schedulerPlaces.map((p) {
      final lastMs = _lastVisitByPlace[p.id];
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
          final group = place.groupId != null
              ? _groups.where((g) => g.id == place.groupId).firstOrNull
              : null;

          String daysLabel;
          if (days == 0) {
            daysLabel = 'Heute';
          } else if (days > 0) {
            daysLabel = 'in $days ${days == 1 ? 'Tag' : 'Tagen'}';
          } else {
            daysLabel = '${-days} ${(-days) == 1 ? 'Tag' : 'Tage'} überfällig';
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
                              'Intervall: ${place.intervalDays} Tage',
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

  void _showPlaceFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.clear),
            title: const Text('Alle Orte'),
            selected: _filterPlaceId == null,
            onTap: () {
              setState(() => _filterPlaceId = null);
              Navigator.pop(ctx);
            },
          ),
          ..._places.map(
            (p) => ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(p.name),
              selected: _filterPlaceId == p.id,
              onTap: () {
                setState(() => _filterPlaceId = p.id);
                Navigator.pop(ctx);
              },
            ),
          ),
        ],
      ),
    );
  }
}
