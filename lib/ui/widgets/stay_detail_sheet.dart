import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../models/person.dart';
import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../models/stay_activity.dart';
import '../../models/stay_person.dart';
import '../../services/database_service.dart';
import 'place_bottom_sheet.dart';
import 'photo_grid.dart';

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
  SavedPlace? _place;
  bool _loading = true;

  late DateTime _startDt;
  late DateTime? _endDt;
  late bool _isInterval;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.stay.notes);
    _startDt = widget.stay.startDateTime;
    _endDt = widget.stay.endDateTime;
    _isInterval = widget.stay.isInterval;
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final stayUuid = widget.stay.uuid;
    final results = await Future.wait([
      DatabaseService.instance.loadPersonsForStay(stayUuid),
      DatabaseService.instance.loadActivitiesForStay(stayUuid),
      DatabaseService.instance.loadAllPersons(),
      DatabaseService.instance.loadAllActivities(),
    ]);
    SavedPlace? place;
    if (widget.stay.placeUuid != null) {
      final places = await DatabaseService.instance.loadAllPlaces();
      place = places.where((p) => p.uuid == widget.stay.placeUuid).firstOrNull;
    }
    if (mounted) {
      setState(() {
        _stayPersons = results[0] as List<StayPerson>;
        _stayActivities = results[1] as List<StayActivity>;
        _allPersons = results[2] as List<Person>;
        _allActivities = results[3] as List<Activity>;
        _place = place;
        _loading = false;
      });
    }
  }

  Future<void> _deleteStay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aufenthalt löschen'),
        content: const Text(
          'Soll dieser Aufenthalt wirklich gelöscht werden? Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await DatabaseService.instance.deleteStay(widget.stay.uuid);
    if (mounted) {
      Navigator.pop(context);
      widget.onUpdated?.call();
    }
  }

  Future<void> _save() async {
    final updated = widget.stay.copyWith(
      notes: _notesCtrl.text.trim(),
      startTime: _startDt.millisecondsSinceEpoch,
      endTime: _endDt?.millisecondsSinceEpoch,
      isInterval: _isInterval,
    );
    await DatabaseService.instance.updateStay(updated);
    widget.onUpdated?.call();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startDt : (_endDt ?? _startDt);
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startDt = picked;
      } else {
        _endDt = picked;
      }
    });
  }

  void _openPlaceSheet() {
    final place = _place;
    if (place == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlaceBottomSheet(
        place: place,
        onUpdated: _load,
        onDeleted: () {
          Navigator.pop(context);
          widget.onUpdated?.call();
        },
      ),
    );
  }

  String _fmtDt(DateTime dt) {
    final d =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d  $t';
  }

  Future<void> _addPersonFromList(Person person) async {
    final sp = StayPerson(
      stayUuid: widget.stay.uuid,
      personUuid: person.uuid,
      name: person.name,
    );
    await DatabaseService.instance.insertStayPerson(sp);
    await _load();
  }

  Future<void> _addPersonAdhoc(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final sp = StayPerson(stayUuid: widget.stay.uuid, name: trimmed);
    await DatabaseService.instance.insertStayPerson(sp);
    await _load();
  }

  Future<void> _removeStayPerson(StayPerson sp) async {
    await DatabaseService.instance.deleteStayPerson(sp.uuid);
    await _load();
  }

  Future<void> _addActivityFromList(Activity activity) async {
    final sa = StayActivity(
      stayUuid: widget.stay.uuid,
      activityUuid: activity.uuid,
      description: activity.name,
    );
    await DatabaseService.instance.insertStayActivity(sa);
    await _load();
  }

  Future<void> _addActivityAdhoc(String description) async {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return;
    final sa = StayActivity(stayUuid: widget.stay.uuid, description: trimmed);
    await DatabaseService.instance.insertStayActivity(sa);
    await _load();
  }

  Future<void> _removeStayActivity(StayActivity sa) async {
    await DatabaseService.instance.deleteStayActivity(sa.uuid);
    await _load();
  }

  void _showAddPersonDialog() {
    final controller = TextEditingController();
    // Persons already added
    final addedPersonUuids = _stayPersons
        .map((p) => p.personUuid)
        .whereType<String>()
        .toSet();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom:
              MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).padding.bottom +
              16,
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
                .where((p) => !addedPersonUuids.contains(p.uuid))
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
        .map((a) => a.activityUuid)
        .whereType<String>()
        .toSet();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom:
              MediaQuery.of(ctx).viewInsets.bottom +
              MediaQuery.of(ctx).padding.bottom +
              16,
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
                .where((a) => !addedActivityIds.contains(a.uuid))
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
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
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
                  // ── Header ───────────────────────────────────────────
                  Row(
                    children: [
                      Text(
                        'Aufenthalt bearbeiten',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      if (_place != null)
                        Flexible(
                          child: TextButton.icon(
                            onPressed: _openPlaceSheet,
                            icon: const Icon(Icons.edit_location_alt, size: 16),
                            label: Text(
                              _place!.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── Start-Zeit ────────────────────────────────────────
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('Beginn'),
                    subtitle: Text(_fmtDt(_startDt)),
                    trailing: const Icon(Icons.edit, size: 18),
                    onTap: () => _pickDateTime(isStart: true),
                  ),
                  // ── End-Zeit ──────────────────────────────────────────
                  if (_endDt != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.stop_circle_outlined),
                      title: const Text('Ende'),
                      subtitle: Text(_fmtDt(_endDt!)),
                      trailing: const Icon(Icons.edit, size: 18),
                      onTap: () => _pickDateTime(isStart: false),
                    ),
                  const SizedBox(height: 4),
                  // ── Notes ─────────────────────────────────────────────
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notizen',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  // ── Intervall-Besuch ──────────────────────────────────
                  if (_place?.intervalEnabled == true) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Intervall-Besuch'),
                      subtitle: const Text(
                        'Besuch zählt zur Intervall-Berechnung',
                      ),
                      value: _isInterval,
                      onChanged: (v) => setState(() => _isInterval = v),
                    ),
                  ],
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
                  // ── Fotos ───────────────────────────────────────
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: const Icon(Icons.photo_library_outlined),
                    title: const Text('Fotos'),
                    children: [
                      PhotoGrid(
                        stayUuid: widget.stay.uuid,
                        placeUuid: widget.stay.placeUuid,
                        includeStayPhotos: false,
                        deviceId: widget.stay.deviceId,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await _save();
                      if (mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Speichern'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _deleteStay,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Aufenthalt löschen'),
                  ),
                ],
              ),
            ),
    );
  }
}
