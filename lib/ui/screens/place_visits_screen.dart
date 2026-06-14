import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

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
  Map<String, List<StayPerson>> _personsByStay = {};
  Map<String, List<StayActivity>> _activitiesByStay = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    final stays = await DatabaseService.instance.loadStaysForPlace(
      widget.place.uuid,
    );
    // Sort newest first, only completed
    final completed =
        stays.where((s) => s.status == StayStatus.completed).toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));

    final personLists = await Future.wait(
      completed.map((s) => DatabaseService.instance.loadPersonsForStay(s.uuid)),
    );
    final activityLists = await Future.wait(
      completed.map(
        (s) => DatabaseService.instance.loadActivitiesForStay(s.uuid),
      ),
    );

    if (mounted) {
      setState(() {
        _stays = completed;
        _personsByStay = {
          for (var i = 0; i < completed.length; i++)
            completed[i].uuid: personLists[i],
        };
        _activitiesByStay = {
          for (var i = 0; i < completed.length; i++)
            completed[i].uuid: activityLists[i],
        };
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.placeVisitsTitle(widget.place.name)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stays.isEmpty
          ? Center(child: Text(l10n.noVisitsYet, textAlign: TextAlign.center))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: _stays.length,
                itemBuilder: (ctx, i) {
                  final stay = _stays[i];
                  return StayCard(
                    stay: stay,
                    place: widget.place,
                    persons: _personsByStay[stay.uuid] ?? [],
                    activities: _activitiesByStay[stay.uuid] ?? [],
                    onUpdated: _load,
                  );
                },
              ),
            ),
    );
  }
}
