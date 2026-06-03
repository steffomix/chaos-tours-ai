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
    if (_searchQuery.isEmpty) return _places;
    final q = _searchQuery.toLowerCase();
    return _places.where((p) {
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
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Suchen',
              onPressed: () => setState(() => _searchActive = true),
            ),
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
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: place.placeType.dotColor.withValues(
                        alpha: 0.15,
                      ),
                      child: Icon(
                        place.placeType.icon,
                        color: place.placeType.dotColor,
                        size: 20,
                      ),
                    ),
                    title: Text(place.name),
                    subtitle: Text(
                      count == 0
                          ? 'Noch nicht besucht'
                          : '$count Besuch${count == 1 ? '' : 'e'}',
                    ),
                    trailing: stay != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _fmtDate(stay.startTime),
                                style: Theme.of(ctx).textTheme.bodySmall,
                              ),
                              Text(
                                '${_fmtTime(stay.startDateTime)}'
                                '${stay.endDateTime != null ? ' – ${_fmtTime(stay.endDateTime!)}' : ''}'
                                '${stay.endDateTime != null ? '  (${_fmtDuration(stay.duration)})' : ''}',
                                style: Theme.of(ctx).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        ctx,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          )
                        : null,
                    onTap: () => _openSheet(place),
                  );
                },
              ),
            ),
    );
  }
}
