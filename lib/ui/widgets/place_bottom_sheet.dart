import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/place_group.dart';
import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';
import '../screens/place_reposition_screen.dart';
import '../screens/place_visits_screen.dart';

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
  int? _groupId;
  List<PlaceGroup> _groups = [];

  bool _intervalEnabled = false;
  late TextEditingController _intervalDaysCtrl;

  int _visitCount = 0;
  int? _lastVisitedAt;

  // Statistics
  List<Stay> _completedStays = [];
  List<String> _distinctPersonNames = [];
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.place.name);
    _notesCtrl = TextEditingController(text: widget.place.notes);
    _radius = widget.place.radius;
    _groupId = widget.place.groupId;
    _intervalEnabled = widget.place.intervalEnabled;
    _intervalDaysCtrl = TextEditingController(
      text: widget.place.intervalDays?.toString() ?? '',
    );
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

  Future<void> _loadStatistics() async {
    final id = widget.place.id;
    if (id == null) return;
    final stays = await DatabaseService.instance.loadStaysForPlace(id);
    final completed =
        stays
            .where((s) => s.status == StayStatus.completed && s.endTime != null)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final persons = await DatabaseService.instance
        .loadDistinctPersonNamesForPlace(id);
    if (mounted) {
      setState(() {
        _completedStays = completed;
        _distinctPersonNames = persons;
        _statsLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _intervalDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _createManualVisit() async {
    final now = DateTime.now();
    final defaultEnd = now.add(const Duration(hours: 1));
    DateTime startDt = now;
    DateTime endDt = defaultEnd;

    String fmtDt(DateTime dt) {
      final d =
          '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
      final t =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$d  $t';
    }

    Future<DateTime?> pickDt(BuildContext ctx, DateTime initial) async {
      final date = await showDatePicker(
        context: ctx,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (date == null) return null;
      if (!ctx.mounted) return null;
      final time = await showTimePicker(
        context: ctx,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null) return null;
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
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
                    'Besuch erstellen',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.place.name,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('Beginn'),
                    subtitle: Text(fmtDt(startDt)),
                    trailing: const Icon(Icons.edit, size: 18),
                    onTap: () async {
                      final picked = await pickDt(ctx, startDt);
                      if (picked != null) setModalState(() => startDt = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.stop_circle_outlined),
                    title: const Text('Ende'),
                    subtitle: Text(fmtDt(endDt)),
                    trailing: const Icon(Icons.edit, size: 18),
                    onTap: () async {
                      final picked = await pickDt(ctx, endDt);
                      if (picked != null) setModalState(() => endDt = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Besuch speichern'),
                    onPressed: () async {
                      final stay = Stay(
                        placeId: widget.place.id,
                        startTime: startDt.millisecondsSinceEpoch,
                        endTime: endDt.millisecondsSinceEpoch,
                        status: StayStatus.completed,
                      );
                      await DatabaseService.instance.insertStay(stay);
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadVisitStats();
                      widget.onUpdated();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final groupId = _groupId;
    final intervalDaysText = _intervalDaysCtrl.text.trim();
    final parsedIntervalDays = int.tryParse(intervalDaysText);
    final updated = widget.place.copyWith(
      name: _nameCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      radius: _radius,
      groupId: groupId,
      clearGroupId: groupId == null,
      intervalEnabled: _intervalEnabled,
      intervalDays: parsedIntervalDays,
      clearIntervalDays: intervalDaysText.isEmpty,
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

  String _fmtDuration(Duration d) {
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}min';
    return '${d.inMinutes}min';
  }

  Duration _medianDuration(List<Duration> durations) {
    final sorted = [...durations]..sort((a, b) => a.compareTo(b));
    final n = sorted.length;
    if (n == 0) return Duration.zero;
    if (n.isOdd) return sorted[n ~/ 2];
    final mid = (sorted[n ~/ 2 - 1].inSeconds + sorted[n ~/ 2].inSeconds) ~/ 2;
    return Duration(seconds: mid);
  }

  Future<void> _openInMaps() async {
    final lat = widget.place.lat;
    final lng = widget.place.lng;
    final name = Uri.encodeComponent(widget.place.name);
    // geo URI opens Google Maps on Android; fallback to https for other platforms
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($name)');
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyGps() {
    final text =
        '${widget.place.lat.toStringAsFixed(6)}, ${widget.place.lng.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('GPS-Koordinaten kopiert')));
  }

  Future<void> _repositionPlace() async {
    if (!mounted) return;
    Navigator.pop(context); // close the bottom sheet first
    final updated = await Navigator.push<SavedPlace>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceRepositionScreen(targetPlace: widget.place),
      ),
    );
    if (updated != null) {
      widget.onUpdated();
    }
  }

  Future<void> _copyReport() async {
    final place = widget.place;
    final db = DatabaseService.instance;
    final id = place.id;

    // Load all completed stays with persons and activities
    final allStays = id != null ? await db.loadStaysForPlace(id) : <Stay>[];
    final completed =
        allStays
            .where((s) => s.status == StayStatus.completed && s.endTime != null)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final group = _groupId != null
        ? _groups.where((g) => g.id == _groupId).firstOrNull
        : null;

    String fmtDt(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.'
          '${d.year}  '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }

    final buf = StringBuffer();

    // ── Header ──────────────────────────────────────────────────────────
    buf.writeln('# ${place.name}');
    buf.writeln();
    buf.writeln('| Feld | Wert |');
    buf.writeln('|------|------|');
    buf.writeln('| Typ | ${place.placeType.label} |');
    buf.writeln(
      '| Koordinaten | ${place.lat.toStringAsFixed(6)}, ${place.lng.toStringAsFixed(6)} |',
    );
    buf.writeln('| Radius | ${place.radius.toStringAsFixed(0)} m |');
    if (group != null) buf.writeln('| Gruppe | ${group.name} |');
    buf.writeln('| Erstellt | ${fmtDt(place.createdAt)} |');
    buf.writeln('| Besuche gesamt | ${completed.length} |');
    if (place.notes.isNotEmpty) {
      buf.writeln();
      buf.writeln('**Notiz:** ${place.notes}');
    }
    buf.writeln();

    // ── Statistics ──────────────────────────────────────────────────────
    if (completed.isNotEmpty) {
      final durations = completed.map((s) => s.duration).toList();
      final totalSec = durations.fold<int>(0, (sum, d) => sum + d.inSeconds);
      final avgDuration = Duration(seconds: totalSec ~/ durations.length);
      final median = _medianDuration(durations);
      final shortest = durations.reduce((a, b) => a < b ? a : b);
      final longest = durations.reduce((a, b) => a > b ? a : b);

      buf.writeln('## Statistik');
      buf.writeln();
      buf.writeln('| | |');
      buf.writeln('|---|---|');
      buf.writeln('| Erster Besuch | ${fmtDt(completed.first.startTime)} |');
      buf.writeln('| Letzter Besuch | ${fmtDt(completed.last.startTime)} |');
      buf.writeln('| Kürzester Besuch | ${_fmtDuration(shortest)} |');
      buf.writeln('| Längster Besuch | ${_fmtDuration(longest)} |');
      buf.writeln('| Durchschnitt | ${_fmtDuration(avgDuration)} |');
      buf.writeln('| Median | ${_fmtDuration(median)} |');

      if (_distinctPersonNames.isNotEmpty) {
        buf.writeln('| Personen | ${_distinctPersonNames.join(', ')} |');
      } else {
        // load if not already loaded
        final persons = id != null
            ? await db.loadDistinctPersonNamesForPlace(id)
            : <String>[];
        if (persons.isNotEmpty) {
          buf.writeln('| Personen | ${persons.join(', ')} |');
        }
      }
      buf.writeln();
    }

    // ── Visits ──────────────────────────────────────────────────────────
    if (completed.isNotEmpty) {
      buf.writeln('## Besuche');
      buf.writeln();
      for (final stay in completed) {
        buf.writeln('### ${fmtDt(stay.startTime)}');
        buf.writeln();
        buf.writeln('| | |');
        buf.writeln('|---|---|');
        buf.writeln('| Start | ${fmtDt(stay.startTime)} |');
        buf.writeln('| Ende | ${fmtDt(stay.endTime!)} |');
        buf.writeln('| Dauer | ${_fmtDuration(stay.duration)} |');
        if (stay.address != null && stay.address!.isNotEmpty) {
          buf.writeln('| Adresse | ${stay.address} |');
        }
        buf.writeln();

        if (stay.id != null) {
          final persons = await db.loadPersonsForStay(stay.id!);
          if (persons.isNotEmpty) {
            buf.writeln(
              '**Personen:** ${persons.map((p) => p.name).join(', ')}  ',
            );
            buf.writeln();
          }
          final activities = await db.loadActivitiesForStay(stay.id!);
          if (activities.isNotEmpty) {
            buf.writeln('**Aktivitäten:**  ');
            for (final a in activities) {
              buf.writeln('- ${a.description}');
            }
            buf.writeln();
          }
        }

        if (stay.notes.isNotEmpty) {
          buf.writeln('**Notiz:** ${stay.notes}  ');
          buf.writeln();
        }
      }
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bericht in Zwischenablage kopiert')),
      );
    }
  }

  Widget _buildStats() {
    if (!_statsLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_completedStays.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('Noch keine Besuche aufgezeichnet.'),
      );
    }

    final durations = _completedStays.map((s) => s.duration).toList();
    final totalSec = durations.fold<int>(0, (sum, d) => sum + d.inSeconds);
    final avgDuration = Duration(seconds: totalSec ~/ durations.length);
    final median = _medianDuration(durations);

    final first = _completedStays.first;
    final last = _completedStays.last;
    final shortest = durations.reduce((a, b) => a < b ? a : b);
    final longest = durations.reduce((a, b) => a > b ? a : b);

    String fmtDt(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}  '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statRow('Erster Besuch', fmtDt(first.startTime)),
          _statRow('Letzter Besuch', fmtDt(last.startTime)),
          _statRow('Kürzester Besuch', _fmtDuration(shortest)),
          _statRow('Längster Besuch', _fmtDuration(longest)),
          _statRow('Durchschnitt', _fmtDuration(avgDuration)),
          _statRow('Median', _fmtDuration(median)),
          if (_distinctPersonNames.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Text(
              'Personen:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _distinctPersonNames
                  .map(
                    (name) => Chip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      avatar: const Icon(Icons.person, size: 14),
                      label: Text(name, style: const TextStyle(fontSize: 12)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Titelzeile ─────────────────────────────────────────────
            Row(
              children: [
                Icon(
                  widget.place.placeType.icon,
                  color: widget.place.placeType.dotColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ort bearbeiten',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.map_outlined),
                  tooltip: 'In Google Maps öffnen',
                  onPressed: _openInMaps,
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all),
                  tooltip: 'Bericht kopieren',
                  onPressed: _copyReport,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ── Origin badge ────────────────────────────────────────────
            if (widget.place.originType != PlaceOriginType.self)
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      widget.place.originType == PlaceOriginType.auto
                          ? Icons.autorenew
                          : Icons.download,
                      size: 14,
                    ),
                    label: Text(
                      widget.place.originType == PlaceOriginType.auto
                          ? 'Automatisch erstellt'
                          : 'Importiert',
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            const SizedBox(height: 4),
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
            // ── HR Statistik ─────────────────────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(child: Divider()),
                Text("Statistik", style: TextStyle(color: Colors.grey)),
                Expanded(child: Divider()),
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
                const Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Erstellt: ${_formatDate(widget.place.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ── Statistik ───────────────────────────────────────────────
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.bar_chart),
              title: const Text('Statistik'),
              onExpansionChanged: (expanded) {
                if (expanded && !_statsLoaded) _loadStatistics();
              },
              children: [_buildStats()],
            ),
            const SizedBox(height: 4),
            // ── Besuche ────────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: widget.place.id == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaceVisitsScreen(place: widget.place),
                      ),
                    ),
              icon: const Icon(Icons.history),
              label: Text(
                _visitCount == 0
                    ? 'Besuche anzeigen'
                    : 'Besuche anzeigen ($_visitCount)',
              ),
            ),
            const SizedBox(height: 8),
            // ── Jetzt besuchen ─────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: widget.place.id == null ? null : _createManualVisit,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Jetzt besuchen'),
            ),
            const SizedBox(height: 12),
            // ── HR Ortseinstellungen ─────────────────────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(child: Divider()),
                Text("Ortseinstellungen", style: TextStyle(color: Colors.grey)),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 4),
            // ── GPS-Koordinaten ────────────────────────────────────────
            InkWell(
              onTap: _copyGps,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
            const SizedBox(height: 8),
            // ── Position ändern ────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: _repositionPlace,
              icon: const Icon(Icons.edit_location_alt),
              label: const Text('Position auf Karte ändern'),
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
            // ── Gruppe ─────────────────────────────────────────────────
            DropdownButtonFormField<int?>(
              initialValue: _groupId == null
                  ? null
                  : (_groups.any((g) => g.id == _groupId) ? _groupId : null),
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
                  (g) => DropdownMenuItem(
                    value: g.id,
                    child: Row(
                      children: [
                        Icon(
                          g.placeType.icon,
                          size: 16,
                          color: g.placeType.dotColor,
                        ),
                        const SizedBox(width: 6),
                        Text(g.name),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _groupId = v),
            ),
            const SizedBox(height: 12),
            // ── Besuchs-Intervall ──────────────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Besuchs-Intervall'),
              subtitle: const Text(
                'Regelmäßige Erinnerung, diesen Ort zu besuchen',
              ),
              value: _intervalEnabled,
              onChanged: (v) => setState(() => _intervalEnabled = v),
            ),
            if (_intervalEnabled) ...[
              const SizedBox(height: 4),
              TextFormField(
                controller: _intervalDaysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Intervall (Tage)',
                  hintText: 'z. B. 14',
                  border: OutlineInputBorder(),
                  suffixText: 'Tage',
                ),
                onChanged: (v) {},
              ),
            ],
            const SizedBox(height: 12),
            // ── Aktionen ───────────────────────────────────────────────
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
