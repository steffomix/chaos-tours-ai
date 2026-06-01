import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  late PlaceType _placeType;
  int? _groupId;
  List<PlaceGroup> _groups = [];

  int _visitCount = 0;
  int? _lastVisitedAt;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.place.name);
    _notesCtrl = TextEditingController(text: widget.place.notes);
    _radius = widget.place.radius;
    _placeType = widget.place.placeType;
    _groupId = widget.place.groupId;
    _loadGroups();
    _loadVisitStats();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseService.instance.loadAllPlaceGroups();
    if (mounted) setState(() => _groups = groups);
  }

  Future<void> _loadVisitStats() async {
    final id = widget.place.id;
    if (id == null) return;
    final count = await DatabaseService.instance.visitCountForPlace(id);
    final last = await DatabaseService.instance.lastVisitedAtForPlace(id);
    if (mounted) {
      setState(() {
        _visitCount = count;
        _lastVisitedAt = last;
      });
    }
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
      placeType: _placeType,
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

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}'
        '  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _copyGps() {
    final text =
        '${widget.place.lat.toStringAsFixed(6)}, ${widget.place.lng.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GPS-Koordinaten kopiert')),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Titelzeile ─────────────────────────────────────────────
            Row(
              children: [
                Icon(_placeType.icon, color: _placeType.dotColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ort bearbeiten',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all),
                  tooltip: 'GPS-Koordinaten kopieren',
                  onPressed: _copyGps,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ── Besuchsstatistik ───────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.history, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _visitCount == 0
                      ? 'Noch nicht besucht'
                      : '$_visitCount Besuch${_visitCount == 1 ? '' : 'e'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_lastVisitedAt != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '· zuletzt ${_formatDate(_lastVisitedAt!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                const Icon(Icons.add_circle_outline,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Erstellt: ${_formatDate(widget.place.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Name ───────────────────────────────────────────────────
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // ── Notiz ──────────────────────────────────────────────────
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notiz',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            // ── Typ ────────────────────────────────────────────────────
            const Text('Typ:'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: PlaceType.values.map((t) {
                final selected = _placeType == t;
                return ChoiceChip(
                  avatar: Icon(
                    t.icon,
                    size: 16,
                    color: selected ? Colors.white : t.dotColor,
                  ),
                  label: Text(t.label),
                  selected: selected,
                  selectedColor: t.dotColor,
                  labelStyle: TextStyle(color: selected ? Colors.white : null),
                  onSelected: (_) => setState(() => _placeType = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // ── Radius ─────────────────────────────────────────────────
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
            // ── Gruppe ─────────────────────────────────────────────────
            DropdownButtonFormField<int?>(
              initialValue: _groupId,
              decoration: const InputDecoration(
                labelText: 'Gruppe',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Keine Gruppe')),
                ..._groups.map(
                  (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                ),
              ],
              onChanged: (v) => setState(() => _groupId = v),
            ),
            const SizedBox(height: 12),
            // ── GPS-Koordinaten ────────────────────────────────────────
            InkWell(
              onTap: _copyGps,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.place.lat.toStringAsFixed(6)}, '
                        '${widget.place.lng.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    ),
                    const Icon(Icons.copy, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Aktionen ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Löschen',
                        style: TextStyle(color: Colors.red)),
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
