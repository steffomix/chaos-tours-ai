import 'package:flutter/material.dart';

import '../../models/saved_place.dart';
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
  Map<int, int?> _lastVisited = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.refreshNotifier?.addListener(_loadPlaces);
    _loadPlaces();
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_loadPlaces);
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    setState(() => _loading = true);
    final places = await DatabaseService.instance.loadAllPlaces();
    final counts = <int, int>{};
    final last = <int, int?>{};
    for (final p in places) {
      if (p.id != null) {
        counts[p.id!] = await DatabaseService.instance.visitCountForPlace(
          p.id!,
        );
        last[p.id!] = await DatabaseService.instance.lastVisitedAtForPlace(
          p.id!,
        );
      }
    }
    if (mounted) {
      setState(() {
        _places = places;
        _visitCounts = counts;
        _lastVisited = last;
        _loading = false;
      });
    }
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Orte')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _places.isEmpty
          ? const Center(
              child: Text(
                'Keine Orte gespeichert.\nOrte auf der Karte per Langer Druck hinzufügen.',
                textAlign: TextAlign.center,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPlaces,
              child: ListView.builder(
                itemCount: _places.length,
                itemBuilder: (ctx, i) {
                  final place = _places[i];
                  final count = _visitCounts[place.id] ?? 0;
                  final last = place.id != null ? _lastVisited[place.id] : null;
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
                    trailing: last != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatDate(last),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                place.placeType.label,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: place.placeType.dotColor),
                              ),
                            ],
                          )
                        : Text(
                            place.placeType.label,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: place.placeType.dotColor),
                          ),
                    onTap: () => _openSheet(place),
                  );
                },
              ),
            ),
    );
  }
}
