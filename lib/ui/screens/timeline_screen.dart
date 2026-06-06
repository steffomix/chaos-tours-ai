import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../models/stay_activity.dart';
import '../../models/stay_person.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
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
  Map<int, List<StayPerson>> _personsByStay = {};
  Map<int, List<StayActivity>> _activitiesByStay = {};
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
    ]);

    final stays = results[0] as List<Stay>;
    final places = results[1] as List<SavedPlace>;

    // Load relations for all stays
    final personLists = await Future.wait(
      stays.map((s) => DatabaseService.instance.loadPersonsForStay(s.id!)),
    );
    final activityLists = await Future.wait(
      stays.map((s) => DatabaseService.instance.loadActivitiesForStay(s.id!)),
    );

    if (mounted) {
      setState(() {
        _stays = stays;
        _places = places;
        _personsByStay = {
          for (var i = 0; i < stays.length; i++) stays[i].id!: personLists[i],
        };
        _activitiesByStay = {
          for (var i = 0; i < stays.length; i++) stays[i].id!: activityLists[i],
        };
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
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.list), text: 'Liste'),
                      Tab(icon: Icon(Icons.map), text: 'Karte'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(children: [_buildList(), _buildMap()]),
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
    final pathEntries = staysWithCoords.where((e) => e.place != null).toList()
      ..sort((a, b) => a.stay.startTime.compareTo(b.stay.startTime));

    final pathPoints = pathEntries
        .map((e) => LatLng(e.place!.lat, e.place!.lng))
        .toList();

    // Gradient: transparent (oldest/past) → opaque teal (newest/present)
    List<Color>? gradientColors;
    if (pathPoints.length >= 2) {
      final n = pathPoints.length;
      gradientColors = List.generate(n, (i) {
        final opacity = i / (n - 1); // 0.0 … 1.0
        return Colors.teal.withValues(alpha: opacity * 0.9);
      });
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
            if (pathPoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: pathPoints,
                    strokeWidth: 3.0,
                    color: Colors.teal.withValues(alpha: 0.6),
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
