import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/activity.dart';
import '../../models/person.dart';
import '../../models/place_photo.dart';
import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../models/stay_activity.dart';
import '../../models/stay_person.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../utils/unified_widget.dart';
import '../photo/all_photos_screen.dart';
import '../p2p_message/p2p_messages_screen.dart';
import '../place/place_detail_screen.dart';

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
  List<PlacePhoto> _stayPhotos = [];

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
      DatabaseService.instance.loadPhotosForStay(stayUuid),
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
        _stayPhotos = results[4] as List<PlacePhoto>;
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaceDetailScreen(
          place: place,
          onUpdated: _load,
          onDeleted: () {
            Navigator.pop(context);
            widget.onUpdated?.call();
          },
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
    return '${m}min';
  }

  Future<void> _copyReport() async {
    final stay = widget.stay;
    final buf = StringBuffer();

    buf.writeln('# Aufenthalt${_place != null ? ': ${_place!.name}' : ''}');
    buf.writeln();
    buf.writeln('| Feld | Wert |');
    buf.writeln('|------|------|');
    buf.writeln('| Start | ${_fmtDt(_startDt)} |');
    if (_endDt != null) {
      buf.writeln('| Ende | ${_fmtDt(_endDt!)} |');
      final dur = _endDt!.difference(_startDt);
      buf.writeln('| Dauer | ${_fmtDuration(dur)} |');
    }
    if (stay.address != null && (stay.address?.isNotEmpty ?? false)) {
      buf.writeln('| Adresse | ${stay.address} |');
    }
    if (_isInterval) buf.writeln('| Typ | Intervall-Besuch |');
    buf.writeln();

    if (_notesCtrl.text.trim().isNotEmpty) {
      buf.writeln('**Notiz:** ${_notesCtrl.text.trim()}');
      buf.writeln();
    }

    if (_stayPersons.isNotEmpty) {
      buf.writeln(
        '**Personen:** ${_stayPersons.map((p) => p.name).join(', ')}',
      );
      buf.writeln();
    }

    if (_stayActivities.isNotEmpty) {
      buf.writeln('**Aktivitäten:**');
      for (final a in _stayActivities) {
        buf.writeln('- ${a.description}');
      }
      buf.writeln();
    }

    if (_stayPhotos.isNotEmpty) {
      buf.writeln('**Fotos:** ${_stayPhotos.length}');
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bericht kopiert')));
    }
  }

  String _fmtDt(DateTime dt) {
    final d =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d  $t';
  }

  String _fmtMs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return _fmtDt(dt);
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
              AppLocalizations.of(ctx)!.addPersonSheetTitle,
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
              decoration: InputDecoration(
                labelText: AppLocalizations.of(ctx)!.personNewHint,
                border: const OutlineInputBorder(),
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
              child: Text(AppLocalizations.of(ctx)!.add),
            ),
          ],
        ),
      ),
    );
  }

  // ── Photos ─────────────────────────────────────────────────────────────────

  Future<void> _addStayPhoto({required ImageSource source}) async {
    final s = SettingsService.instance;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: s.photoImageQuality,
      maxWidth: s.photoMaxWidth == 0 ? null : s.photoMaxWidth.toDouble(),
      maxHeight: s.photoMaxHeight == 0 ? null : s.photoMaxHeight.toDouble(),
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final photo = PlacePhoto(
      placeUuid: widget.stay.placeUuid,
      stayUuid: widget.stay.uuid,
      photoData: bytes,
      takenAt: DateTime.now().millisecondsSinceEpoch,
    );
    await DatabaseService.instance.insertPlacePhoto(
      photo,
      deviceId: widget.stay.deviceId,
    );
    await _load();
  }

  void _openFullViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StayPhotoViewer(
          photos: _stayPhotos,
          initialIndex: index,
          onChanged: _load,
        ),
      ),
    );
  }

  void _openAllStayPhotos(AppLocalizations l10n) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AllPhotosScreen.forStay(
          stayUuid: widget.stay.uuid,
          title: l10n.allPhotosScreenTitle,
          subtitle: _place?.name,
        ),
      ),
    );
  }

  Widget _buildPhotosSection(AppLocalizations l10n) {
    final n = SettingsService.instance.placeDetailPhotoCount;
    final inlinePhotos = _stayPhotos.take(n).toList();
    final totalCount = _stayPhotos.length;
    final hasMore = totalCount > n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Add photo buttons ──────────────────────────────────────────────
        Row(
          children: [
            Text(l10n.photos, style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.camera_alt, size: 20),
              tooltip: l10n.camera,
              onPressed: () => _addStayPhoto(source: ImageSource.camera),
            ),
            IconButton(
              icon: const Icon(Icons.add_photo_alternate, size: 20),
              tooltip: l10n.fromGallery,
              onPressed: () => _addStayPhoto(source: ImageSource.gallery),
            ),
          ],
        ),
        if (_stayPhotos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.noPlacePhotos,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          )
        else ...[
          ...inlinePhotos.asMap().entries.map((entry) {
            final photo = entry.value;
            final bytes = photo.photoData;
            final hasData = bytes.isNotEmpty;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () => _openFullViewer(entry.key),
                    child: hasData
                        ? Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          )
                        : Container(
                            height: 120,
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                      _fmtMs(photo.takenAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  if (photo.caption.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: Text(
                        photo.caption,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          }),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton.icon(
                onPressed: () => _openAllStayPhotos(l10n),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.showAllPhotosButton(totalCount)),
              ),
            ),
        ],
      ],
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
              AppLocalizations.of(ctx)!.addActivitySheetTitle,
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
              decoration: InputDecoration(
                labelText: AppLocalizations.of(ctx)!.activityNewHint,
                border: const OutlineInputBorder(),
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
              child: Text(AppLocalizations.of(ctx)!.add),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                      if (defaultTargetPlatform == TargetPlatform.linux)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          onPressed: () => Navigator.pop(context),
                        ),
                      Flexible(
                        child: Text(
                          l10n.editStay,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_place != null)
                        Icon(
                          Icons.arrow_right_alt,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      if (_place != null)
                        Tooltip(
                          message: l10n.openPlaceSettings,
                          child: TextButton.icon(
                            onPressed: _openPlaceSheet,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.edit_location_alt, size: 24),
                            label: const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── Start-Zeit ────────────────────────────────────────
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline),
                    title: Text(l10n.begin),
                    subtitle: Text(_fmtDt(_startDt)),
                    trailing: const Icon(Icons.edit, size: 18),
                    onTap: () => _pickDateTime(isStart: true),
                  ),
                  // ── End-Zeit ──────────────────────────────────────────
                  if (_endDt != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.stop_circle_outlined),
                      title: Text(l10n.end),
                      subtitle: Text(_fmtDt(_endDt!)),
                      trailing: const Icon(Icons.edit, size: 18),
                      onTap: () => _pickDateTime(isStart: false),
                    ),
                  const SizedBox(height: 4),
                  // ── Notes ─────────────────────────────────────────────
                  TextField(
                    controller: _notesCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.notes,
                      border: const OutlineInputBorder(),
                    ),
                    minLines: 3,
                    maxLines: 20,
                  ),
                  // ── Intervall-Besuch ──────────────────────────────────
                  if (_place?.intervalEnabled == true) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.intervalVisit),
                      subtitle: Text(l10n.intervalVisitSubtitle),
                      value: _isInterval,
                      onChanged: (v) => setState(() => _isInterval = v),
                    ),
                  ],

                  // Persons
                  if (_place != null &&
                      SettingsService.instance.messengerEnabled) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MessagesScreen.place(
                            placeUuid: _place!.uuid,
                            title: _place!.name,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.forum),
                      label: const Text('P2P Nachrichten'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          l10n.persons,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.person_add),
                          onPressed: _showAddPersonDialog,
                          tooltip: l10n.addPersonSheetTitle,
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
                          l10n.activities,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add_task),
                          onPressed: _showAddActivityDialog,
                          tooltip: l10n.addActivitySheetTitle,
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
                    _buildPhotosSection(l10n),
                    const SizedBox(height: 16),
                    // ── Bericht / P2P Nachrichten ─────────────────────────
                    OutlinedButton.icon(
                      onPressed: _copyReport,
                      icon: const Icon(Icons.copy_all),
                      label: const Text('Bericht kopieren'),
                    ),
                  ],
                  const SizedBox(height: 16),

                  UnifiedWidget(context).saveAndDeleteButtonsRow(
                    onSavePressed: () async {
                      await _save();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    onDeletePressed: _deleteStay,
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Full-screen viewer for stay photos ──────────────────────────────────────

class _StayPhotoViewer extends StatefulWidget {
  final List<PlacePhoto> photos;
  final int initialIndex;
  final VoidCallback onChanged;

  const _StayPhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.onChanged,
  });

  @override
  State<_StayPhotoViewer> createState() => _StayPhotoViewerState();
}

class _StayPhotoViewerState extends State<_StayPhotoViewer> {
  late PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.photoDeleteTitle),
        content: Text(l10n.photoDeleteContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await DatabaseService.instance.softDeletePlacePhoto(
      widget.photos[_index].uuid,
    );
    widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  String _fmtMs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final photo = widget.photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_index + 1} / ${widget.photos.length}',
              style: const TextStyle(color: Colors.white),
            ),
            Text(
              _fmtMs(photo.takenAt),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: l10n.delete,
            onPressed: _delete,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          final b = widget.photos[i].photoData;
          return InteractiveViewer(
            child: Center(
              child: b.isNotEmpty
                  ? Image.memory(b)
                  : const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
            ),
          );
        },
      ),
    );
  }
}
