import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/virtual_device.dart';
import '../../models/place_group.dart';
import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../models/sync_source.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../services/telegram_service.dart';
import '../../services/settings_service.dart';
import '../../utils/maidenhead.dart';
import '../../utils/unified_widget.dart';
import '../photo/photos_section.dart';
import 'place_experiences_screen.dart';
import 'place_map_reposition_screen.dart';
import '../stay/stays_screen.dart';
import '../p2p_message/p2p_messages_screen.dart';
import 'places_screen.dart';
import '../settings/sync_options_dialog.dart';

class PlaceDetailScreen extends StatefulWidget {
  final SavedPlace place;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;

  const PlaceDetailScreen({
    super.key,
    required this.place,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _notesCtrl;
  late double _radius;
  String? _groupUuid;
  List<PlaceGroup> _groups = [];

  late TextEditingController _websiteCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;

  bool _intervalEnabled = false;
  late TextEditingController _intervalDaysCtrl;

  // ── P2P Sync fields ─────────────────────────────────────────────────────
  late TextEditingController _syncUrlCtrl;
  late TextEditingController _syncPortCtrl;
  late TextEditingController _syncApiKeyCtrl;
  late TextEditingController _syncNotesCtrl;
  late SyncSourceOptions _syncOptions;
  int _syncIntervalMinutes = 0;
  bool _isSyncing = false;

  List<VirtualDevice> _importProtectedVirtualDevices = [];

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
    _websiteCtrl = TextEditingController(text: widget.place.website);
    _emailCtrl = TextEditingController(text: widget.place.email);
    _phoneCtrl = TextEditingController(text: widget.place.phone);
    _radius = widget.place.radius;
    _groupUuid = widget.place.groupUuid;
    _intervalEnabled = widget.place.intervalEnabled;
    _intervalDaysCtrl = TextEditingController(
      text: widget.place.intervalDays?.toString() ?? '',
    );
    _syncUrlCtrl = TextEditingController(text: widget.place.syncUrl);
    _syncPortCtrl = TextEditingController(
      text: widget.place.syncPort.toString(),
    );
    _syncApiKeyCtrl = TextEditingController(text: widget.place.syncApiKey);
    _syncNotesCtrl = TextEditingController(text: widget.place.syncNotes);
    _syncOptions = widget.place.syncOptions;
    _syncIntervalMinutes = widget.place.syncIntervalMinutes;
    _loadGroups();
    _loadVisitStats();
    _loadImportProtectedVirtualDevices();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseService.instance.loadAllPlaceGroups();
    if (mounted) setState(() => _groups = groups);
  }

  Future<void> _loadImportProtectedVirtualDevices() async {
    final list = await DatabaseService.instance
        .loadImportProtectedVirtualDevices();
    if (mounted) setState(() => _importProtectedVirtualDevices = list);
  }

  Future<void> _loadVisitStats() async {
    final uuid = widget.place.uuid;
    final count = await DatabaseService.instance.visitCountForPlace(uuid);
    final last = await DatabaseService.instance.lastVisitedAtForPlace(uuid);
    if (mounted) {
      setState(() {
        _visitCount = count;
        _lastVisitedAt = last;
      });
    }
  }

  Future<void> _loadStatistics() async {
    final uuid = widget.place.uuid;
    final stays = await DatabaseService.instance.loadStaysForPlace(uuid);
    final completed =
        stays
            .where((s) => s.status == StayStatus.completed && s.endTime != null)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final persons = await DatabaseService.instance
        .loadDistinctPersonNamesForPlace(uuid);
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
    _websiteCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _intervalDaysCtrl.dispose();
    _syncUrlCtrl.dispose();
    _syncPortCtrl.dispose();
    _syncApiKeyCtrl.dispose();
    _syncNotesCtrl.dispose();
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
                    AppLocalizations.of(ctx)!.createVisitTitle,
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
                    title: Text(AppLocalizations.of(ctx)!.begin),
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
                    title: Text(AppLocalizations.of(ctx)!.end),
                    subtitle: Text(fmtDt(endDt)),
                    trailing: const Icon(Icons.edit, size: 18),
                    onTap: () async {
                      final picked = await pickDt(ctx, endDt);
                      if (picked != null) setModalState(() => endDt = picked);
                    },
                  ),
                  const SizedBox(height: 16),

                  UnifiedWidget(ctx).saveAndCancelButtonsRow(
                    onSavePressed: () {
                      final stay = Stay(
                        placeUuid: widget.place.uuid,
                        startTime: startDt.millisecondsSinceEpoch,
                        endTime: endDt.millisecondsSinceEpoch,
                        status: StayStatus.completed,
                      );
                      DatabaseService.instance.insertStay(stay).then((_) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadVisitStats();
                        widget.onUpdated();
                      });
                    },
                    onCancelPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Returns a short summary of the active sync options for display.
  String _syncOptionsSummary(SyncSourceOptions opts) {
    final active = opts.tables.entries
        .where((e) => e.value.anyEnabled)
        .map((e) => e.key.replaceAll('_', ' '))
        .take(3)
        .join(', ');
    final total = opts.tables.values.where((o) => o.anyEnabled).length;
    if (total == 0) return 'Keine Optionen aktiv';
    if (total > 3) return '$active … ($total Tabellen)';
    return active.isEmpty ? 'Keine Optionen aktiv' : active;
  }

  Future<void> _save() async {
    final groupUuid = _groupUuid;
    final intervalDaysText = _intervalDaysCtrl.text.trim();
    final parsedIntervalDays = int.tryParse(intervalDaysText);
    final syncPort = int.tryParse(_syncPortCtrl.text.trim()) ?? 8000;
    final updated = widget.place.copyWith(
      name: _nameCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      website: _websiteCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      radius: _radius,
      groupUuid: groupUuid,
      clearGroupUuid: groupUuid == null,
      intervalEnabled: _intervalEnabled,
      intervalDays: parsedIntervalDays,
      clearIntervalDays: intervalDaysText.isEmpty,
      syncUrl: _syncUrlCtrl.text.trim(),
      syncPort: syncPort,
      syncApiKey: _syncApiKeyCtrl.text.trim(),
      syncNotes: _syncNotesCtrl.text.trim(),
      syncOptions: _syncOptions,
      syncIntervalMinutes: _syncIntervalMinutes,
    );
    await DatabaseService.instance.updatePlace(updated);
    widget.onUpdated();
    if (mounted) Navigator.pop(context);
  }

  /// Shows a dialog to pick one of the import-protected VirtualDevices, then
  /// inserts a copy of the current place with a new UUID and the selected
  /// device ID, effectively moving it into the "Geschützter Bereich".
  Future<void> _copyToProtectedArea() async {
    if (_importProtectedVirtualDevices.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    VirtualDevice? selected;

    if (_importProtectedVirtualDevices.length == 1) {
      // Only one option — use it directly after confirmation.
      selected = _importProtectedVirtualDevices.first;
    } else {
      // Let the user choose which protected area.
      selected = await showDialog<VirtualDevice>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.copyToProtectedAreaSelectTitle),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                l10n.copyToProtectedAreaSelectSubtitle,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            ..._importProtectedVirtualDevices.map(
              (a) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, a),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.name)),
                  ],
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      );
    }

    if (selected == null || !mounted) return;

    final chosenVirtualDevice = selected;

    // Confirm the operation.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.copyToProtectedAreaSelectTitle),
        content: Text(l10n.copyToProtectedAreaSelectSubtitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.create),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Create a fresh SavedPlace with a new UUID by omitting the uuid parameter
    // (the constructor auto-generates one when uuid is null/empty).
    final copy = SavedPlace(
      name: widget.place.name,
      lat: widget.place.lat,
      lng: widget.place.lng,
      radius: widget.place.radius,
      placeType: widget.place.placeType,
      notes: widget.place.notes,
      groupUuid: widget.place.groupUuid,
      createdAt: now,
      intervalEnabled: widget.place.intervalEnabled,
      intervalDays: widget.place.intervalDays,
      updatedAt: now,
      deviceId: chosenVirtualDevice.deviceId,
      originType: widget.place.originType,
      originSourceUuid: widget.place.originSourceUuid,
      website: widget.place.website,
      email: widget.place.email,
      phone: widget.place.phone,
    );
    await DatabaseService.instance.insertPlace(
      copy,
      deviceId: chosenVirtualDevice.deviceId,
    );

    if (mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaceDetailScreen(
            place: copy,
            onUpdated: () {},
            onDeleted: () {},
          ),
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.copyToProtectedAreaSuccess)));
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctxL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(ctxL10n.placeDeleteTitle),
          content: Text(ctxL10n.placeDeleteContent(widget.place.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctxL10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                ctxL10n.delete,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await DatabaseService.instance.deletePlace(widget.place.uuid);
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
    if (!(Platform.isAndroid || Platform.isIOS)) {
      launchUrl(
        Uri.parse(
          'https://maps.google.com?q=${widget.place.lat},${widget.place.lng}',
        ),
      );
      return;
    }
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
        '${widget.place.lat.toStringAsFixed(6)},${widget.place.lng.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.gpsCopied)),
    );
  }

  void _copyLocator() {
    final loc = Maidenhead.format(
      Maidenhead.encodeId(widget.place.lat, widget.place.lng),
    );
    Clipboard.setData(ClipboardData(text: loc));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.locatorCopied)),
    );
  }

  void _openCompass(CompassReference reference) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PlacesScreen(
          compassMode: true,
          compassTargetUuid: widget.place.uuid,
          compassReference: reference,
        ),
      ),
    );
  }

  Future<void> _repositionPlace() async {
    if (!mounted) return;
    Navigator.pop(context); // close the bottom sheet first
    final updated = await Navigator.push<SavedPlace>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceMapRepositionScreen(targetPlace: widget.place),
      ),
    );
    if (updated != null) {
      widget.onUpdated();
    }
  }

  Future<void> _copyReport({bool basicReport = false}) async {
    final place = widget.place;
    final db = DatabaseService.instance;
    final uuid = place.uuid;

    // Load all completed stays with persons and activities
    final allStays = await db.loadStaysForPlace(uuid);
    final completed =
        allStays
            .where((s) => s.status == StayStatus.completed && s.endTime != null)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final group = _groupUuid != null
        ? _groups.where((g) => g.uuid == _groupUuid).firstOrNull
        : null;

    String fmtDt(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.'
          '${d.year}  '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }

    Future<void> toClipboard(String text) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.reportCopied)),
        );
      }
    }

    if (!mounted) return;
    final buf = StringBuffer();
    // ── Header ──────────────────────────────────────────────────────────
    buf.writeln('# ${place.name}');
    buf.writeln();
    buf.writeln('| Feld | Wert |');
    buf.writeln('|------|------|');
    buf.writeln('| Typ | ${place.placeType.l10nLabel(context)} |');

    buf.writeln('| UUID | ${place.uuid} |');
    if (place.originSourceUuid != null) {
      buf.writeln('| Ursprung UUID | ${place.originSourceUuid} |');
    }
    buf.writeln('| Device ID | ${place.deviceId} |');
    buf.writeln(
      '| GPS Koordinaten | ${place.lat.toStringAsFixed(6)}, ${place.lng.toStringAsFixed(6)} |',
    );
    buf.writeln(
      '| QTH Koordinaten | ${Maidenhead.encode(place.lat, place.lng, pairs: 6)} |',
    );
    buf.writeln('| Email | ${place.email} |');
    buf.writeln('| Telefon | ${place.phone} |');
    buf.writeln('| Radius | ${place.radius.toStringAsFixed(0)} m |');
    if (group != null) buf.writeln('| Gruppe | ${group.name} |');
    buf.writeln('| Erstellt | ${fmtDt(place.createdAt)} |');
    buf.writeln('| Aktualisiert am | ${fmtDt(place.updatedAt)} |');
    buf.writeln('| Besuche gesamt | ${completed.length} |');
    if (place.notes.isNotEmpty) {
      buf.writeln();
      buf.writeln('**Notiz:** ${place.notes}');
    }
    buf.writeln();

    if (basicReport) {
      await toClipboard(buf.toString());
      return;
    }

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
        final persons = await db.loadDistinctPersonNamesForPlace(uuid);
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

        final persons = await db.loadPersonsForStay(stay.uuid);
        if (persons.isNotEmpty) {
          buf.writeln(
            '**Personen:** ${persons.map((p) => p.name).join(', ')}  ',
          );
          buf.writeln();
        }
        final activities = await db.loadActivitiesForStay(stay.uuid);
        if (activities.isNotEmpty) {
          buf.writeln('**Aktivitäten:**  ');
          for (final a in activities) {
            buf.writeln('- ${a.description}');
          }
          buf.writeln();
        }

        if (stay.notes.isNotEmpty) {
          buf.writeln('**Notiz:** ${stay.notes}  ');
          buf.writeln();
        }
      }
    }

    // ── Experiences ─────────────────────────────────────────────────
    if (uuid.isNotEmpty) {
      final experiences = await db.loadExperiencesForPlace(uuid);
      if (experiences.isNotEmpty) {
        buf.writeln('## Survival-Erfahrungen');
        buf.writeln();
        for (final exp in experiences) {
          buf.writeln(
            '**Ø ${exp.averageRating.toStringAsFixed(1)}**'
            '  _(${fmtDt(exp.createdAt)})_',
          );
          buf.writeln();
          buf.writeln('| Kategorie | Bewertung |');
          buf.writeln('|-----------|-----------|');
          buf.writeln(
            '| Gefährlich ↔ Freundlich | ${exp.ratingDangerousFriendly} |',
          );
          buf.writeln(
            '| Betrügerisch ↔ Zuverlässig | ${exp.ratingFraudReliable} |',
          );
          buf.writeln(
            '| Abweisend ↔ Bietet Unterkunft | ${exp.ratingDismissiveAccommodation} |',
          );
          buf.writeln('| Fordert ↔ Bietet Verpflegung | ${exp.ratingFood} |');
          buf.writeln(
            '| Fordert ↔ Bietet Equipment | ${exp.ratingEquipment} |',
          );
          buf.writeln(
            '| Fordert ↔ Bietet Transport | ${exp.ratingTransport} |',
          );
          buf.writeln('| Fordert ↔ Bietet Medizin | ${exp.ratingMedicine} |');
          if (exp.text.isNotEmpty) {
            buf.writeln();
            buf.writeln('> ${exp.text}');
          }
          buf.writeln();
        }
      }
    }

    await toClipboard(buf.toString());
    return;
  }

  Future<void> _sendToTelegram() async {
    final group = _groupUuid != null
        ? _groups.where((g) => g.uuid == _groupUuid).firstOrNull
        : null;
    final connUuid = group?.telegramConnectionUuid;
    if (connUuid == null) return;

    final conn = await DatabaseService.instance.loadTelegramConnection(
      connUuid,
    );
    if (conn == null) return;

    // Build report text (plain text, escaping Markdown V2 special characters)
    final place = widget.place;
    final db = DatabaseService.instance;
    final uuid = place.uuid;

    final allStays = await db.loadStaysForPlace(uuid);
    final completed =
        allStays
            .where((s) => s.status == StayStatus.completed && s.endTime != null)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    String fmtDt(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.'
          '${d.year} '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }

    // Escape Markdown V2 special chars
    String esc(String s) => s.replaceAllMapped(
      RegExp(r'[_*\[\]()~`>#+\-=|{}.!\\]'),
      (m) => '\\${m[0]}',
    );
    if (!mounted) return;
    final buf = StringBuffer();
    buf.writeln('*${esc(place.name)}*');
    buf.writeln();
    buf.writeln('Typ: ${esc(place.placeType.l10nLabel(context))}');
    buf.writeln(
      'Koordinaten: ${esc(place.lat.toStringAsFixed(6))}, ${esc(place.lng.toStringAsFixed(6))}',
    );
    if (group != null) buf.writeln('Gruppe: ${esc(group.name)}');
    buf.writeln('Besuche: ${esc(completed.length.toString())}');
    if (place.notes.isNotEmpty) {
      buf.writeln();
      buf.writeln(esc(place.notes));
    }

    if (completed.isNotEmpty) {
      final durations = completed.map((s) => s.duration).toList();
      final totalSec = durations.fold<int>(0, (sum, d) => sum + d.inSeconds);
      final avgDuration = Duration(seconds: totalSec ~/ durations.length);
      buf.writeln();
      buf.writeln('*Statistik*');
      buf.writeln('Erster Besuch: ${esc(fmtDt(completed.first.startTime))}');
      buf.writeln('Letzter Besuch: ${esc(fmtDt(completed.last.startTime))}');
      buf.writeln('Durchschnitt: ${esc(_fmtDuration(avgDuration))}');
    }

    if (!mounted) return;
    // Show confirmation dialog before sending
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ctxL10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(ctxL10n.telegramSendTitle),
          content: Text(ctxL10n.telegramSendContent(place.name, conn.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctxL10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctxL10n.send),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final result = await TelegramService.instance.sendMessage(
      conn,
      buf.toString(),
    );

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? l10n.telegramSent
                : l10n.telegramError(result.errorMessage ?? ''),
          ),
          backgroundColor: result.success ? null : Colors.red,
        ),
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
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(AppLocalizations.of(context)!.noVisitsRecorded),
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
          _statRow(
            AppLocalizations.of(context)!.statFirstVisit,
            fmtDt(first.startTime),
          ),
          _statRow(
            AppLocalizations.of(context)!.statLastVisit,
            fmtDt(last.startTime),
          ),
          _statRow(
            AppLocalizations.of(context)!.statShortest,
            _fmtDuration(shortest),
          ),
          _statRow(
            AppLocalizations.of(context)!.statLongest,
            _fmtDuration(longest),
          ),
          _statRow(
            AppLocalizations.of(context)!.statAverage,
            _fmtDuration(avgDuration),
          ),
          _statRow(
            AppLocalizations.of(context)!.statMedian,
            _fmtDuration(median),
          ),
          if (_distinctPersonNames.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.persons,
              style: const TextStyle(fontWeight: FontWeight.w500),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              widget.place.placeType.icon,
              color: widget.place.placeType.dotColor,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.placeEditTitle)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: l10n.openInGoogleMaps,
            onPressed: _openInMaps,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 16),
            child: UnifiedWidget(context).saveButton(onPressed: _save),
          ),
        ],
      ),
      body: Padding(
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
              // ── Origin badge ────────────────────────────────────────────
              if (widget.place.originType != PlaceOriginType.self)
                Row(
                  mainAxisSize: MainAxisSize.max,
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
                            ? l10n.placeOriginAuto
                            : l10n.placeOriginImported,
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
                decoration: InputDecoration(
                  labelText: l10n.name,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // ── Notiz ──────────────────────────────────────────────────
              TextField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: l10n.noteName,
                  border: const OutlineInputBorder(),
                ),
                minLines: 3,
                maxLines: 20,
              ),
              const SizedBox(height: 12),
              // ── Website / Email / Telefon ──────────────────────────────
              _ContactField(
                controller: _websiteCtrl,
                labelText: l10n.website,
                icon: Icons.language,
                keyboardType: TextInputType.url,
                onLaunch: () async {
                  final raw = _websiteCtrl.text.trim();
                  if (raw.isEmpty) return;
                  final url = raw.startsWith('http') ? raw : 'https://$raw';
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              const SizedBox(height: 8),
              _ContactField(
                controller: _emailCtrl,
                labelText: l10n.email,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                onLaunch: () async {
                  final raw = _emailCtrl.text.trim();
                  if (raw.isEmpty) return;
                  final uri = Uri(scheme: 'mailto', path: raw);
                  await launchUrl(uri);
                },
              ),
              const SizedBox(height: 8),
              _ContactField(
                controller: _phoneCtrl,
                labelText: l10n.phone,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                onLaunch: () async {
                  final raw = _phoneCtrl.text.trim();
                  if (raw.isEmpty) return;
                  final uri = Uri(scheme: 'tel', path: raw);
                  await launchUrl(uri);
                },
              ),
              // ── Fotos ──────────────────────────────────────────────────
              ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.photos),
                children: [
                  PhotosSection(
                    placeUuid: widget.place.uuid,
                    placeName: widget.place.name,
                    deviceId: widget.place.deviceId,
                  ),
                ],
              ),

              UnifiedWidget(context).namedDivider(l10n.navVisits),
              OutlinedButton.icon(
                onPressed: widget.place.uuid.isEmpty
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StaysScreen(place: widget.place),
                        ),
                      ),
                icon: const Icon(Icons.history),
                label: Text(
                  _visitCount == 0
                      ? l10n.showVisits
                      : l10n.showVisitsCount(_visitCount),
                ),
              ),
              const SizedBox(height: 8),
              // ── Jetzt besuchen ─────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: widget.place.uuid.isEmpty
                    ? null
                    : _createManualVisit,
                icon: const Icon(Icons.add_location_alt),
                label: Text(l10n.visitNow),
              ),
              // ── Besuchs-Intervall ──────────────────────────────────────
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.visitInterval),
                subtitle: Text(l10n.visitIntervalSubtitle),
                value: _intervalEnabled,
                onChanged: (v) => setState(() => _intervalEnabled = v),
              ),
              if (_intervalEnabled) ...[
                const SizedBox(height: 4),
                TextFormField(
                  controller: _intervalDaysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.intervalDaysLabel,
                    hintText: l10n.intervalDaysHint,
                    border: const OutlineInputBorder(),
                    suffixText: l10n.intervalDaysSuffix,
                  ),
                  onChanged: (v) {},
                ),
              ],
              // ── Gruppe ─────────────────────────────────────────────────
              UnifiedWidget(
                context,
              ).namedDivider(AppLocalizations.of(context)!.placeGroupsTitle),
              DropdownButtonFormField<String?>(
                initialValue: _groupUuid == null
                    ? null
                    : (_groups.any((g) => g.uuid == _groupUuid)
                          ? _groupUuid
                          : null),
                decoration: InputDecoration(
                  labelText: l10n.group,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.noGroup)),
                  ..._groups.map(
                    (g) => DropdownMenuItem(
                      value: g.uuid,
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
                onChanged: (v) => setState(() => _groupUuid = v),
              ),

              ListTile(
                leading: const Icon(Icons.folder),
                title: Text(l10n.managePlaceGroups),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pushNamed(context, '/place-groups').then((_) {
                    if (mounted) _loadGroups();
                  });
                },
              ),
              const SizedBox(height: 12),
              // ── Bericht an Telegram ────────────────────────────────────
              if (_groupUuid != null &&
                  _groups
                          .where((g) => g.uuid == _groupUuid)
                          .firstOrNull
                          ?.telegramConnectionUuid !=
                      null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _sendToTelegram,
                  icon: const Icon(Icons.send),
                  label: Text(l10n.sendReportToTelegram),
                ),
              ],
              // ── HR P2P Sync ────────────────────────────────────────────────────────
              UnifiedWidget(
                context,
              ).namedDivider(l10n.sectionP2pMessengerAndValuation),
              // ── Survival-Erfahrungen ─────────────────────────────────────
              OutlinedButton.icon(
                onPressed: widget.place.uuid.isEmpty
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ExperiencesScreen(
                            placeUuid: widget.place.uuid,
                            placeName: widget.place.name,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.night_shelter),
                label: Text(l10n.survivalExperiences),
              ),
              const SizedBox(height: 12),
              // ── Nachrichten zum Ort ────────────────────────────────────
              if (SettingsService.instance.messengerEnabled)
                OutlinedButton.icon(
                  onPressed: widget.place.uuid.isEmpty
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => MessagesScreen.place(
                              placeUuid: widget.place.uuid,
                              title: widget.place.name,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.forum),
                  label: Text(l10n.placeMessagesButton),
                ),
              if (SettingsService.instance.messengerEnabled)
                const SizedBox(height: 8),
              // ── P2P Sync Konfiguration ─────────────────────────────────
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync),
                title: const Text('P2P Sync konfigurieren'),
                subtitle: widget.place.syncUrl.isEmpty
                    ? const Text(
                        'Nicht konfiguriert',
                        style: TextStyle(fontSize: 12),
                      )
                    : Text(
                        '${widget.place.syncUrl}:${widget.place.syncPort}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                children: [
                  const SizedBox(height: 8),
                  TextField(
                    controller: _syncUrlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://192.168.4.1',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _syncPortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '8000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.settings_ethernet),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _syncApiKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _syncNotesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notizen',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  // ── Sync-Optionen ──────────────────────────────────────
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.tune),
                    title: const Text('Sync-Optionen'),
                    subtitle: Text(
                      _syncOptionsSummary(_syncOptions),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final result = await showSyncOptionsDialog(
                        context,
                        _syncOptions,
                      );
                      if (result != null && mounted) {
                        setState(() => _syncOptions = result);
                      }
                    },
                  ),
                  // ── Auto-Sync Intervall ────────────────────────────────
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(
                      _syncIntervalMinutes == 0
                          ? 'Auto-Sync: Aus'
                          : 'Auto-Sync: alle $_syncIntervalMinutes Min',
                    ),
                    subtitle: const Text(
                      '0 = deaktiviert, sonst 10–600 Min',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  Slider(
                    value: _syncIntervalMinutes.toDouble(),
                    min: 0,
                    max: 600,
                    divisions: 60,
                    label: _syncIntervalMinutes == 0
                        ? 'Aus'
                        : '$_syncIntervalMinutes Min',
                    onChanged: (v) => setState(
                      () => _syncIntervalMinutes = (v / 10).round() * 10,
                    ),
                  ),
                  if (widget.place.syncLastMs > 0) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'Letzter Sync: ${_formatDate(widget.place.syncLastMs)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // ── Jetzt Synchronisieren ─────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_isSyncing || _syncUrlCtrl.text.isEmpty)
                              ? null
                              : () async {
                                  // Save current URL/port/key changes first
                                  final syncPort =
                                      int.tryParse(_syncPortCtrl.text.trim()) ??
                                      8000;
                                  final tempPlace = widget.place.copyWith(
                                    syncUrl: _syncUrlCtrl.text.trim(),
                                    syncPort: syncPort,
                                    syncApiKey: _syncApiKeyCtrl.text.trim(),
                                    syncOptions: _syncOptions,
                                  );
                                  setState(() => _isSyncing = true);
                                  final result = await SyncService.instance
                                      .syncWithPlaceConfig(tempPlace);
                                  if (!mounted) return;
                                  setState(() => _isSyncing = false);
                                  final msg = result.success
                                      ? '✓ ${result.sourceName}: ↓${result.pulled} ↑${result.pushed}'
                                      : '✗ ${result.errorMessage ?? 'Fehler'}';
                                  // ignore: use_build_context_synchronously
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(msg),
                                      backgroundColor: result.success
                                          ? null
                                          : Colors.red,
                                    ),
                                  );
                                },
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync),
                          label: const Text('Jetzt Synchronisieren'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── P2P Nachrichten ────────────────────────────────────
                  OutlinedButton.icon(
                    onPressed: widget.place.uuid.isEmpty
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => MessagesScreen.place(
                                placeUuid: widget.place.uuid,
                                title: widget.place.name,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.forum),
                    label: const Text('P2P Nachrichten'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              const SizedBox(height: 4),
              // ── HR GPS Einstellungen ─────────────────────────────────────────────────
              UnifiedWidget(
                context,
              ).namedDivider(AppLocalizations.of(context)!.gpsSettings),
              // ── Radius ändern ────────────────────────────────────────
              Text(
                AppLocalizations.of(
                  context,
                )!.radius(_radius.toStringAsFixed(0)),
              ),
              Slider(
                value: _radius,
                min: 10,
                max: 500,
                divisions: 49,
                label: '${_radius.toStringAsFixed(0)} m',
                onChanged: (v) => setState(() => _radius = v),
              ),
              const SizedBox(height: 12),
              // ── Position ändern ────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _repositionPlace,
                icon: const Icon(Icons.edit_location_alt),
                label: Text(AppLocalizations.of(context)!.changePositionOnMap),
              ),
              const SizedBox(height: 12),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lat: ${widget.place.lat.toStringAsFixed(6)}, '
                          'Lng: ${widget.place.lng.toStringAsFixed(6)}',
                        ),
                      ),
                      const Icon(Icons.copy, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Maidenhead-Locator (QTH, 6+4) ──────────────────────────
              InkWell(
                onTap: _copyLocator,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_on,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'QTH: ${Maidenhead.format(Maidenhead.encodeId(widget.place.lat, widget.place.lng))}',
                        ),
                      ),
                      const Icon(Icons.copy, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Mit Kompass … (Bezugspunkt wählbar) ────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.place.uuid.isEmpty
                          ? null
                          : () => _openCompass(CompassReference.here),
                      icon: const Icon(Icons.my_location),
                      label: Text(
                        AppLocalizations.of(context)!.compassFromHere,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.place.uuid.isEmpty
                          ? null
                          : () => _openCompass(CompassReference.place),
                      icon: const Icon(Icons.place),
                      label: Text(
                        AppLocalizations.of(context)!.compassFromPlace,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ── HR Statistik ─────────────────────────────────────────────────
              UnifiedWidget(
                context,
              ).namedDivider(AppLocalizations.of(context)!.infoAndStats),
              const SizedBox(height: 4),
              // ── Besuchsstatistik ───────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.history, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _visitCount == 0
                        ? AppLocalizations.of(context)!.neverVisited
                        : (_visitCount == 1
                              ? AppLocalizations.of(
                                  context,
                                )!.visitCount(_visitCount)
                              : AppLocalizations.of(
                                  context,
                                )!.visitCountPlural(_visitCount)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_lastVisitedAt != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.lastVisitedAt(_formatDate(_lastVisitedAt!)),
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
                    AppLocalizations.of(
                      context,
                    )!.placeCreatedAt(_formatDate(widget.place.createdAt)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // ── Statistik ───────────────────────────────────────────────
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.bar_chart),
                title: Text(AppLocalizations.of(context)!.statistics),
                onExpansionChanged: (expanded) {
                  if (expanded && !_statsLoaded) _loadStatistics();
                },
                children: [_buildStats()],
              ),
              // ── Bericht kopieren ───────────────────────────────────────
              OutlinedButton.icon(
                onPressed: () => _copyReport(basicReport: true),
                icon: const Icon(Icons.copy_all),
                label: Text(AppLocalizations.of(context)!.copyBasicReport),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _copyReport(basicReport: false),
                icon: const Icon(Icons.copy_all),
                label: Text(AppLocalizations.of(context)!.copyFullReport),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  AppLocalizations.of(context)!.copyReportHint,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              Divider(),
              const SizedBox(height: 12),
              // ── UUID ────────────────────────────────────────────
              Text(
                "UUID",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.place.uuid,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.place.uuid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.uuidCopied,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // ── Device ID ────────────────────────────────────────────
              Text(
                "Device ID",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.place.deviceId,
                      style: const TextStyle(fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.place.deviceId),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.deviceIdCopied,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    iconSize: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 12),
              // ── In geschützten Bereich kopieren ───────────────────────
              if (_importProtectedVirtualDevices.isNotEmpty &&
                  !_importProtectedVirtualDevices
                      .map((a) => a.deviceId)
                      .contains(widget.place.deviceId)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _copyToProtectedArea,
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(
                    AppLocalizations.of(context)!.copyToProtectedArea,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    AppLocalizations.of(context)!.copyToProtectedAreaHint,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
              Divider(),
              const SizedBox(height: 12),
              // ── Aktionen ───────────────────────────────────────────────
              Row(
                children: [
                  UnifiedWidget(context).deleteButton(onPressed: _delete),
                  Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A text field with a leading icon and a tappable launch button on the right.
class _ContactField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final TextInputType keyboardType;
  final VoidCallback onLaunch;

  const _ContactField({
    required this.controller,
    required this.labelText,
    required this.icon,
    required this.keyboardType,
    required this.onLaunch,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: const Icon(Icons.open_in_new),
          tooltip: AppLocalizations.of(context)!.openLabel(labelText),
          onPressed: onLaunch,
        ),
      ),
    );
  }
}
