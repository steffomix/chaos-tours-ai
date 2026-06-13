import 'dart:math';

import 'package:flutter/material.dart';
import 'package:focus_detector/focus_detector.dart';

import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';
import '../../services/foreground_service_handler.dart';
import '../../services/location_service.dart';
import '../../utils/geo_utils.dart';
import '../widgets/place_bottom_sheet.dart';
import '../widgets/experience_filter_panel.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  List<SavedPlace> _places = [];
  Map<int, int> _visitCounts = {};
  Map<int, Stay?> _lastStay = {};
  Map<String, double> _avgRatings = {};

  // Search
  bool _searchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Filter
  bool _intervalOnly = false;
  bool _filterPanelOpen = false;
  ExperienceFilterState _expFilter = const ExperienceFilterState();

  // Distance
  ({double lat, double lng})? _currentPos;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _loadCurrentPosition();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onServiceData(Object data) {
    _loadPlaces();
    _loadCurrentPosition();
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final pos = await LocationService.instance.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() => _currentPos = (lat: pos.latitude, lng: pos.longitude));
      }
    } catch (_) {}
  }

  Future<void> _loadPlaces() async {
    final places = await DatabaseService.instance.loadAllPlaces();
    final counts = <int, int>{};
    final stays = <int, Stay?>{};
    for (final p in places) {
      if (p.id != null) {
        counts[p.id!] = await DatabaseService.instance.visitCountForPlace(p.id!);
        stays[p.id!] = await DatabaseService.instance.lastCompletedStayForPlace(p.id!);
      }
    }
    final avgRatings = await DatabaseService.instance.loadAverageRatingsForAllPlaces();
    if (mounted) {
      setState(() {
        _places = places;
        _visitCounts = counts;
        _lastStay = stays;
        _avgRatings = avgRatings;
      });
    }
  }

  List<({SavedPlace place, double? distance})> get _filtered {
    var list = _places;
    if (_intervalOnly) {
      list = list.where((p) => p.intervalEnabled).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        if (p.name.toLowerCase().contains(q)) return true;
        if (p.notes.toLowerCase().contains(q)) return true;
        if (p.placeType.label.toLowerCase().contains(q)) return true;
        return false;
      }).toList();
    }

    // Apply experience filter.
    if (_expFilter.isActive) {
      list = list.where((p) {
        if (p.uuid.isEmpty) return !_expFilter.requireExperiences;
        final avg = _avgRatings[p.uuid];
        if (avg == null) return !_expFilter.requireExperiences;
        return avg >= _expFilter.minAvgRating;
      }).toList();
    }

    // Compute distances.
    final pos = _currentPos;
    List<({SavedPlace place, double? distance})> result;
    if (_expFilter.distanceEnabled && pos != null) {
      // Bounding-box pre-filter.
      final maxM = _expFilter.maxDistanceKm * 1000;
      final latDelta = maxM / 111000;
      final lngDelta = maxM / (111000 * cos(pos.lat * pi / 180).abs().clamp(0.001, 1.0));

      final candidates = list.where((p) =>
          (p.lat - pos.lat).abs() <= latDelta &&
          (p.lng - pos.lng).abs() <= lngDelta).toList();

      // Haversine exact distance.
      result = candidates.map((p) {
        final d = GeoUtils.distanceMeters(pos.lat, pos.lng, p.lat, p.lng);
        return (place: p, distance: d);
      }).where((e) => e.distance <= maxM).toList();

      // Sort: distance first, then average rating descending.
      result.sort((a, b) {
        final distCmp = a.distance!.compareTo(b.distance!);
        if (distCmp != 0) return distCmp;
        final rA = _avgRatings[a.place.uuid] ?? 0;
        final rB = _avgRatings[b.place.uuid] ?? 0;
        return rB.compareTo(rA);
      });
    } else {
      result = list.map((p) => (place: p, distance: null)).toList();
    }

    return result;
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return FocusDetector(
      onFocusGained: () =>
          ForegroundServiceManager.addDataListener(_onServiceData),
      onFocusLost: () =>
          ForegroundServiceManager.removeDataListener(_onServiceData),
      child: Scaffold(
        appBar: AppBar(
          title: _searchActive
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Orte durchsuchen…',
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                )
              : const Text('Orte'),
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
              IconButton(
                icon: Badge(
                  isLabelVisible: _intervalOnly,
                  child: const Icon(Icons.schedule),
                ),
                tooltip: _intervalOnly ? 'Alle Orte anzeigen' : 'Nur Intervall-Orte',
                onPressed: () => setState(() => _intervalOnly = !_intervalOnly),
              ),
              IconButton(
                icon: Badge(
                  isLabelVisible: _filterActive,
                  child: const Icon(Icons.filter_list),
                ),
                tooltip: 'Filter',
                onPressed: () =>
                    setState(() => _filterPanelOpen = !_filterPanelOpen),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Suchen',
                onPressed: () => setState(() => _searchActive = true),
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            if (_filterPanelOpen)
              ExperienceFilterPanel(
                filter: _expFilter,
                onChanged: (f) => setState(() => _expFilter = f),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isNotEmpty || _expFilter.isActive
                            ? 'Keine Orte gefunden.'
                            : 'Keine Orte gespeichert.\n'
                                'Orte auf der Karte per Langer Druck hinzufügen.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPlaces,
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final item = filtered[i];
                          final place = item.place;
                          final count = _visitCounts[place.id] ?? 0;
                          final stay = place.id != null ? _lastStay[place.id] : null;
                          return _PlaceCard(
                            place: place,
                            count: count,
                            lastStay: stay,
                            distance: item.distance,
                            avgRating: place.uuid.isNotEmpty
                                ? _avgRatings[place.uuid]
                                : null,
                            fmtDate: _fmtDate,
                            fmtTime: _fmtTime,
                            fmtDuration: _fmtDuration,
                            fmtDistance: _fmtDistance,
                            onTap: () => _openSheet(place),
                          );
                        },
                      ),
                    ),
            ),
          ],
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
                  Icon(place.placeType.icon, color: place.placeType.dotColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      place.name,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
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
                count == 0 ? 'Noch nicht besucht' : '$count Besuch${count == 1 ? '' : 'e'}',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              if (lastStay != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Zuletzt: ${fmtDate(lastStay!.startTime)}  '
                  '${fmtTime(lastStay!.startDateTime)}'
                  '${lastStay!.endDateTime != null ? ' – ${fmtTime(lastStay!.endDateTime!)}' : ''}'
                  '${lastStay!.endDateTime != null ? '  (${fmtDuration(lastStay!.duration)})' : ''}',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
              if (place.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(place.notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
