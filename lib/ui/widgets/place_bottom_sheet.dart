import 'package:flutter/material.dart';

import '../../models/place_group.dart';
import '../../models/saved_place.dart';
import '../../services/database_service.dart';

class PlaceBottomSheet extends StatefulWidget {
  final SavedPlace place;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;

  const PlaceBottomSheet({
    super.key,
    required this.place,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<PlaceBottomSheet> createState() => _PlaceBottomSheetState();
}

class _PlaceBottomSheetState extends State<PlaceBottomSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _notesCtrl;
  late double _radius;
  late int _colorType;
  int? _groupId;
  List<PlaceGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.place.name);
    _notesCtrl = TextEditingController(text: widget.place.notes);
    _radius = widget.place.radius;
    _colorType = widget.place.colorType;
    _groupId = widget.place.groupId;
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseService.instance.loadAllPlaceGroups();
    if (mounted) setState(() => _groups = groups);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final groupId = _groupId;
    final updated = widget.place.copyWith(
      name: _nameCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      radius: _radius,
      colorType: _colorType,
      groupId: groupId,
      clearGroupId: groupId == null,
    );
    await DatabaseService.instance.updatePlace(updated);
    widget.onUpdated();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ort löschen?'),
        content: Text('„${widget.place.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseService.instance.deletePlace(widget.place.id!);
    widget.onDeleted();
    if (mounted) Navigator.pop(context);
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ort bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notizen',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Text('Radius: ${_radius.toStringAsFixed(0)} m'),
            Slider(
              value: _radius,
              min: 10,
              max: 500,
              divisions: 49,
              label: '${_radius.toStringAsFixed(0)} m',
              onChanged: (v) => setState(() => _radius = v),
            ),
            const SizedBox(height: 8),
            const Text('Farbe:'),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(PlaceColorType.values.length, (i) {
                final colorType = PlaceColorType.values[i];
                return GestureDetector(
                  onTap: () => setState(() => _colorType = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorType.color,
                      border: Border.all(
                        color: _colorType == i
                            ? colorType.borderColor
                            : Colors.grey,
                        width: _colorType == i ? 3 : 1,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            // Group dropdown
            DropdownButtonFormField<int?>(
              value: _groupId,
              decoration: const InputDecoration(
                labelText: 'Gruppe',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Keine Gruppe'),
                ),
                ..._groups.map(
                  (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                ),
              ],
              onChanged: (v) => setState(() => _groupId = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'Löschen',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Speichern'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
