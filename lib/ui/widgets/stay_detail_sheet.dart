import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/person.dart';
import '../../models/stay.dart';
import '../../models/stay_activity.dart';
import '../../models/stay_person.dart';
import '../../services/database_service.dart';

class StayDetailSheet extends StatefulWidget {
  final Stay stay;
  final VoidCallback? onUpdated;

  const StayDetailSheet({super.key, required this.stay, this.onUpdated});

  @override
  State<StayDetailSheet> createState() => _StayDetailSheetState();
}

class _StayDetailSheetState extends State<StayDetailSheet> {
  late TextEditingController _notesCtrl;
  List<StayPerson> _stayPersons = [];
  List<StayActivity> _stayActivities = [];
  List<Person> _allPersons = [];
  List<Activity> _allActivities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.stay.notes);
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final stayId = widget.stay.id!;
    final results = await Future.wait([
      DatabaseService.instance.loadPersonsForStay(stayId),
      DatabaseService.instance.loadActivitiesForStay(stayId),
      DatabaseService.instance.loadAllPersons(),
      DatabaseService.instance.loadAllActivities(),
    ]);
    if (mounted) {
      setState(() {
        _stayPersons = results[0] as List<StayPerson>;
        _stayActivities = results[1] as List<StayActivity>;
        _allPersons = results[2] as List<Person>;
        _allActivities = results[3] as List<Activity>;
        _loading = false;
      });
    }
  }

  Future<void> _saveNotes() async {
    final updated = widget.stay.copyWith(notes: _notesCtrl.text.trim());
    await DatabaseService.instance.updateStay(updated);
    widget.onUpdated?.call();
  }

  Future<void> _addPersonFromList(Person person) async {
    final sp = StayPerson(
      stayId: widget.stay.id!,
      personId: person.id,
      name: person.name,
    );
    await DatabaseService.instance.insertStayPerson(sp);
    await _load();
  }

  Future<void> _addPersonAdhoc(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final sp = StayPerson(stayId: widget.stay.id!, name: trimmed);
    await DatabaseService.instance.insertStayPerson(sp);
    await _load();
  }

  Future<void> _removeStayPerson(StayPerson sp) async {
    await DatabaseService.instance.deleteStayPerson(sp.id!);
    await _load();
  }

  Future<void> _addActivityFromList(Activity activity) async {
    final sa = StayActivity(
      stayId: widget.stay.id!,
      activityId: activity.id,
      description: activity.name,
    );
    await DatabaseService.instance.insertStayActivity(sa);
    await _load();
  }

  Future<void> _addActivityAdhoc(String description) async {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return;
    final sa = StayActivity(stayId: widget.stay.id!, description: trimmed);
    await DatabaseService.instance.insertStayActivity(sa);
    await _load();
  }

  Future<void> _removeStayActivity(StayActivity sa) async {
    await DatabaseService.instance.deleteStayActivity(sa.id!);
    await _load();
  }

  void _showAddPersonDialog() {
    final controller = TextEditingController();
    // Persons already added
    final addedPersonIds = _stayPersons
        .map((p) => p.personId)
        .whereType<int>()
        .toSet();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Person hinzufügen',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Known persons
            ..._allPersons
                .where((p) => !addedPersonIds.contains(p.id))
                .map(
                  (p) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(p.name),
                    subtitle: p.role.isNotEmpty ? Text(p.role) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _addPersonFromList(p);
                    },
                  ),
                ),
            const Divider(),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Name eingeben (neu)',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (v) {
                Navigator.pop(ctx);
                _addPersonAdhoc(v);
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _addPersonAdhoc(controller.text);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddActivityDialog() {
    final controller = TextEditingController();
    final addedActivityIds = _stayActivities
        .map((a) => a.activityId)
        .whereType<int>()
        .toSet();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tätigkeit hinzufügen',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ..._allActivities
                .where((a) => !addedActivityIds.contains(a.id))
                .map(
                  (a) => ListTile(
                    leading: const Icon(Icons.work_outline),
                    title: Text(a.name),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addActivityFromList(a);
                    },
                  ),
                ),
            const Divider(),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Tätigkeit eingeben (neu)',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (v) {
                Navigator.pop(ctx);
                _addActivityAdhoc(v);
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _addActivityAdhoc(controller.text);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: _loading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Aufenthalt bearbeiten',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  // Notes
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notizen',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onEditingComplete: _saveNotes,
                  ),
                  const SizedBox(height: 16),
                  // Persons
                  Row(
                    children: [
                      Text(
                        'Personen',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.person_add),
                        onPressed: _showAddPersonDialog,
                        tooltip: 'Person hinzufügen',
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    children: _stayPersons
                        .map(
                          (sp) => Chip(
                            avatar: const Icon(Icons.person, size: 16),
                            label: Text(sp.name),
                            onDeleted: () => _removeStayPerson(sp),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  // Activities
                  Row(
                    children: [
                      Text(
                        'Tätigkeiten',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add_task),
                        onPressed: _showAddActivityDialog,
                        tooltip: 'Tätigkeit hinzufügen',
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    children: _stayActivities
                        .map(
                          (sa) => Chip(
                            avatar: const Icon(Icons.work_outline, size: 16),
                            label: Text(sa.description),
                            onDeleted: () => _removeStayActivity(sa),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await _saveNotes();
                      if (mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Speichern'),
                  ),
                ],
              ),
            ),
    );
  }
}
