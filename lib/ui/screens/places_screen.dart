import 'package:flutter/material.dart';

import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';
import '../widgets/place_bottom_sheet.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key, this.refreshNotifier});

  final ValueNotifier<int>? refreshNotifier;

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  List<SavedPlace> _places = [];
  Map<int, int> _visitCounts = {};
  Map<int, Stay?> _lastStay = {};
  bool _loading = true;

  // Search
  bool _searchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Filter
  bool _intervalOnly = false;

  @override
  void initState() {
    super.initState();
    widget.refreshNotifier?.addListener(_loadPlaces);
    _loadPlaces();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_loadPlaces);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    setState(() => _loading = true);
    final places = await DatabaseService.instance.loadAllPlaces();
    final counts = <int, int>{};
    final stays = <int, Stay?>{};
    for (final p in places) {
      if (p.id != null) {
        counts[p.id!] = await DatabaseService.instance.visitCountForPlace(
          p.id!,
        );
        stays[p.id!] = await DatabaseService.instance.lastCompletedStayForPlace(
          p.id!,
        );
      }
    }
    if (mounted) {
      setState(() {
        _places = places;
        _visitCounts = counts;
        _lastStay = stays;
        _loading = false;
      });
    }
  }

  List<SavedPlace> get _filtered {
    var list = _places;
    if (_intervalOnly) {
      list = list.where((p) => p.intervalEnabled).toList();
    }
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((p) {
      if (p.name.toLowerCase().contains(q)) return true;
      if (p.notes.toLowerCase().contains(q)) return true;
      if (p.placeType.label.toLowerCase().contains(q)) return true;
      return false;
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
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
              tooltip: _intervalOnly
                  ? 'Alle Orte anzeigen'
                  : 'Nur Intervall-Orte',
              onPressed: () => setState(() => _intervalOnly = !_intervalOnly),
            ),
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
          : filtered.isEmpty
          ? Center(
              child: Text(
                _searchQuery.isNotEmpty
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
                  final place = filtered[i];
                  final count = _visitCounts[place.id] ?? 0;
                  final stay = place.id != null ? _lastStay[place.id] : null;
                  return _PlaceCard(
                    place: place,
                    count: count,
                    lastStay: stay,
                    fmtDate: _fmtDate,
                    fmtTime: _fmtTime,
                    fmtDuration: _fmtDuration,
                    onTap: () => _openSheet(place),
                  );
                },
              ),
            ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final SavedPlace place;
  final int count;
  final Stay? lastStay;
  final String Function(int ms) fmtDate;
  final String Function(DateTime dt) fmtTime;
  final String Function(Duration d) fmtDuration;
  final VoidCallback onTap;

  const _PlaceCard({
    required this.place,
    required this.count,
    required this.lastStay,
    required this.fmtDate,
    required this.fmtTime,
    required this.fmtDuration,
    required this.onTap,
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
              // Header row: type icon + name + type chip
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
                ],
              ),
              const SizedBox(height: 4),
              // Visit count row
              Text(
                count == 0
                    ? 'Noch nicht besucht'
                    : '$count Besuch${count == 1 ? '' : 'e'}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              // Last stay row
              if (lastStay != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Zuletzt: ${fmtDate(lastStay!.startTime)}  '
                  '${fmtTime(lastStay!.startDateTime)}'
                  '${lastStay!.endDateTime != null ? ' – ${fmtTime(lastStay!.endDateTime!)}' : ''}'
                  '${lastStay!.endDateTime != null ? '  (${fmtDuration(lastStay!.duration)})' : ''}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              // Notes preview
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
