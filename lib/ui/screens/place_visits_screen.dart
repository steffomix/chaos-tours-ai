import 'package:flutter/material.dart';

import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../models/stay_activity.dart';
import '../../models/stay_person.dart';
import '../../services/database_service.dart';
import '../widgets/stay_card.dart';

/// Displays all completed stays recorded at a given [SavedPlace].
class PlaceVisitsScreen extends StatefulWidget {
  final SavedPlace place;

  const PlaceVisitsScreen({super.key, required this.place});

  @override
  State<PlaceVisitsScreen> createState() => _PlaceVisitsScreenState();
}

class _PlaceVisitsScreenState extends State<PlaceVisitsScreen> {
  List<Stay> _stays = [];
  Map<int, List<StayPerson>> _personsByStay = {};
  Map<int, List<StayActivity>> _activitiesByStay = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    final stays = await DatabaseService.instance.loadStaysForPlace(
      widget.place.id!,
    );
    // Sort newest first, only completed
    final completed =
        stays.where((s) => s.status == StayStatus.completed).toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));

    final personLists = await Future.wait(
      completed.map((s) => DatabaseService.instance.loadPersonsForStay(s.id!)),
    );
    final activityLists = await Future.wait(
      completed.map(
        (s) => DatabaseService.instance.loadActivitiesForStay(s.id!),
      ),
    );

    if (mounted) {
      setState(() {
        _stays = completed;
        _personsByStay = {
          for (var i = 0; i < completed.length; i++)
            completed[i].id!: personLists[i],
        };
        _activitiesByStay = {
          for (var i = 0; i < completed.length; i++)
            completed[i].id!: activityLists[i],
        };
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Besuche: ${widget.place.name}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stays.isEmpty
          ? const Center(
              child: Text(
                'Noch keine Besuche aufgezeichnet.',
                textAlign: TextAlign.center,
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _stays.length,
                itemBuilder: (ctx, i) {
                  final stay = _stays[i];
                  return StayCard(
                    stay: stay,
                    place: widget.place,
                    persons: _personsByStay[stay.id] ?? [],
                    activities: _activitiesByStay[stay.id] ?? [],
                    onUpdated: _load,
                  );
                },
              ),
            ),
    );
  }
}
