import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/place_group.dart';
import '../../models/saved_place.dart';
import '../../models/telegram_connection.dart';
import '../../services/calendar_service.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';

class PlaceGroupsScreen extends StatefulWidget {
  const PlaceGroupsScreen({super.key});

  @override
  State<PlaceGroupsScreen> createState() => _PlaceGroupsScreenState();
}

class _PlaceGroupsScreenState extends State<PlaceGroupsScreen> {
  List<PlaceGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groups = await DatabaseService.instance.loadAllPlaceGroups();
    if (mounted) setState(() => _groups = groups);
  }

  Future<void> _addGroup() async {
    final result = await _showEditDialog(null);
    if (result != null) {
      await DatabaseService.instance.insertPlaceGroup(result.$1);
      await SettingsService.instance.setGroupCalendarId(
        result.$1.uuid,
        result.$2,
      );
      await _load();
    }
  }

  Future<void> _editGroup(PlaceGroup group) async {
    final result = await _showEditDialog(group);
    if (result != null) {
      await DatabaseService.instance.updatePlaceGroup(result.$1);
      await SettingsService.instance.setGroupCalendarId(
        result.$1.uuid,
        result.$2,
      );
      await _load();
    }
  }

  Future<void> _deleteGroup(PlaceGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.groupDeleteTitle),
        content: Text(l10n.groupDeleteContent(group.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.instance.deletePlaceGroup(group.uuid);
      await _load();
    }
  }

  Future<(PlaceGroup, String?)?> _showEditDialog(PlaceGroup? existing) async {
    final telegramConnections = await DatabaseService.instance
        .loadAllTelegramConnections();
    if (!mounted) return null;
    return Navigator.push<(PlaceGroup, String?)>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PlaceGroupEditScreen(
          existing: existing,
          telegramConnections: telegramConnections,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.placeGroupsTitle)),
      body: _groups.isEmpty
          ? Center(child: Text(l10n.noGroupsYet))
          : ListView.builder(
              itemCount: _groups.length,
              itemBuilder: (ctx, i) {
                final g = _groups[i];
                return ListTile(
                  leading: Icon(
                    g.isAutoGroup ? Icons.auto_awesome : Icons.folder,
                    color: g.placeType.dotColor,
                  ),
                  title: Text(g.name),
                  subtitle: Row(
                    children: [
                      Icon(
                        g.placeType.icon,
                        size: 14,
                        color: g.placeType.dotColor,
                      ),
                      const SizedBox(width: 4),
                      Text(g.placeType.label),
                      if (SettingsService.instance.getGroupCalendarId(g.uuid) !=
                          null) ...const [
                        SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 14),
                      ],
                      if (g.telegramConnectionUuid != null) ...const [
                        SizedBox(width: 8),
                        Icon(Icons.send, size: 14),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editGroup(g),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteGroup(g),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGroup,
        tooltip: l10n.addGroupTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlaceGroupEditScreen extends StatefulWidget {
  final PlaceGroup? existing;
  final List<TelegramConnection> telegramConnections;

  const _PlaceGroupEditScreen({
    required this.existing,
    required this.telegramConnections,
  });

  @override
  State<_PlaceGroupEditScreen> createState() => _PlaceGroupEditScreenState();
}

class _PlaceGroupEditScreenState extends State<_PlaceGroupEditScreen> {
  late final TextEditingController _nameCtrl;
  String? _calendarId;
  String? _telegramConnectionUuid;
  late bool _includeNotes;
  late bool _includePersons;
  late bool _includeActivities;
  late bool _isAutoGroup;
  late PlaceType _placeType;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _calendarId = e != null
        ? SettingsService.instance.getGroupCalendarId(e.uuid)
        : null;
    _telegramConnectionUuid = e?.telegramConnectionUuid;
    _includeNotes = e?.includeNotes ?? true;
    _includePersons = e?.includePersons ?? true;
    _includeActivities = e?.includeActivities ?? true;
    _isAutoGroup = e?.isAutoGroup ?? false;
    _placeType = e?.placeType ?? PlaceType.public;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> updateTelegramConnections() async {
    final connections = await DatabaseService.instance
        .loadAllTelegramConnections();
    if (mounted) {
      setState(() {
        widget.telegramConnections.clear();
        widget.telegramConnections.addAll(connections);
      });
    }
  }

  Future<void> _pickCalendar() async {
    final granted = await CalendarService.instance.requestPermissions();
    if (!granted) return;
    final calendars = await CalendarService.instance.loadCalendars();
    if (!mounted) return;
    final id = await showDialog<String>(
      context: context,
      builder: (dCtx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            const Icon(Icons.calendar_month),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(dCtx)!.pickCalendar),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: calendars
                .map(
                  (c) => ListTile(
                    title: Text(c.name ?? ''),
                    subtitle: Text(c.accountName ?? ''),
                    onTap: () => Navigator.pop(dCtx, c.id),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (id != null) setState(() => _calendarId = id);
  }

  Future<void> _movePlaces() async {
    if (widget.existing == null) return;
    final l10n = AppLocalizations.of(context)!;

    final allGroups = await DatabaseService.instance.loadAllPlaceGroups();
    final otherGroups = allGroups
        .where((g) => g.uuid != widget.existing!.uuid && g.deletedAt == null)
        .toList();
    if (!mounted) return;

    // null = no group (pre-selected default)
    String? picked;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDlg) {
          final dlgL10n = AppLocalizations.of(dCtx)!;
          return AlertDialog(
            title: Text(dlgL10n.movePlacesTitle),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  RadioListTile<String?>(
                    value: null,
                    groupValue: picked,
                    title: Text(dlgL10n.noGroup),
                    onChanged: (v) => setDlg(() => picked = v),
                  ),
                  ...otherGroups.map(
                    (g) => RadioListTile<String?>(
                      value: g.uuid,
                      groupValue: picked,
                      title: Text(g.name),
                      onChanged: (v) => setDlg(() => picked = v),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: Text(dlgL10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: Text(dlgL10n.moveButton),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    final allPlaces = await DatabaseService.instance.loadAllPlaces();
    final groupPlaces = allPlaces
        .where((p) => p.groupUuid == widget.existing!.uuid)
        .toList();

    for (final place in groupPlaces) {
      await DatabaseService.instance.updatePlace(
        place.copyWith(groupUuid: picked, clearGroupUuid: picked == null),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.placesMovedCount(groupPlaces.length))),
      );
    }
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final group = PlaceGroup(
      uuid: widget.existing?.uuid,
      name: name,
      telegramConnectionUuid: _telegramConnectionUuid,
      includeNotes: _includeNotes,
      includePersons: _includePersons,
      includeActivities: _includeActivities,
      isAutoGroup: _isAutoGroup,
      placeType: _placeType,
    );
    Navigator.pop(context, (group, _calendarId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? l10n.newGroup : l10n.editGroup),
        actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Name
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l10n.name,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.autoGroup),
              subtitle: Text(l10n.autoGroupSubtitle),
              value: _isAutoGroup,
              onChanged: (v) => setState(() => _isAutoGroup = v ?? false),
            ),
            const Divider(),
            const SizedBox(height: 4),

            // PlaceType
            Text(l10n.type, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
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

            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),
            // Telegram connection picker
            if (widget.telegramConnections.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _telegramConnectionUuid,
                decoration: const InputDecoration(
                  labelText: 'Telegram',
                  prefixIcon: Icon(Icons.send),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.none)),
                  ...widget.telegramConnections.map(
                    (c) => DropdownMenuItem(value: c.uuid, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _telegramConnectionUuid = v),
              ),
            ],

            ListTile(
              leading: const Icon(Icons.send),
              title: Text(l10n.telegramConnections),
              subtitle: Text(l10n.telegramConnectionsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/telegram-connections')
                  .then((value) async {
                    await updateTelegramConnections();
                    if (mounted) setState(() {});
                  }),
            ),
            const Divider(),

            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),
            // Calendar picker
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text(
                  _calendarId != null ? l10n.calendarChosen : l10n.noCalendar,
                ),
                subtitle: _calendarId != null ? Text(_calendarId!) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: _pickCalendar,
                    ),
                    if (_calendarId != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _calendarId = null),
                      ),
                  ],
                ),
              ),
            ),

            // Checkboxes
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.notesInCalendar),
              value: _includeNotes,
              onChanged: (v) => setState(() => _includeNotes = v ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.personsInCalendar),
              value: _includePersons,
              onChanged: (v) => setState(() => _includePersons = v ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.activitiesInCalendar),
              value: _includeActivities,
              onChanged: (v) => setState(() => _includeActivities = v ?? true),
            ),

            // Move places (only when editing an existing group)
            if (widget.existing != null) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text(l10n.movePlacesTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: _movePlaces,
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
