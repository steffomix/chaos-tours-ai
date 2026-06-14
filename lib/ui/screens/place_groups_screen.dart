import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/place_group.dart';
import '../../models/saved_place.dart';
import '../../services/calendar_service.dart';
import '../../services/database_service.dart';

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
      await DatabaseService.instance.insertPlaceGroup(result);
      await _load();
    }
  }

  Future<void> _editGroup(PlaceGroup group) async {
    final result = await _showEditDialog(group);
    if (result != null) {
      await DatabaseService.instance.updatePlaceGroup(result);
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

  Future<PlaceGroup?> _showEditDialog(PlaceGroup? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String? calendarId = existing?.calendarId;
    String? telegramConnectionUuid = existing?.telegramConnectionUuid;
    bool includeNotes = existing?.includeNotes ?? true;
    bool includePersons = existing?.includePersons ?? true;
    bool includeActivities = existing?.includeActivities ?? true;
    bool isAutoGroup = existing?.isAutoGroup ?? false;
    PlaceType placeType = existing?.placeType ?? PlaceType.public;

    // Load available telegram connections for the picker
    final telegramConnections = await DatabaseService.instance
        .loadAllTelegramConnections();

    return showDialog<PlaceGroup>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final l10n = AppLocalizations.of(ctx)!;
          return AlertDialog(
            title: Text(existing == null ? l10n.newGroup : l10n.editGroup),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.name,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Calendar picker
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      calendarId != null
                          ? l10n.calendarChosen
                          : l10n.noCalendar,
                    ),
                    subtitle: calendarId != null ? Text(calendarId!) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final id = await _pickCalendar(ctx);
                            if (id != null) setS(() => calendarId = id);
                          },
                        ),
                        if (calendarId != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setS(() => calendarId = null),
                          ),
                      ],
                    ),
                  ),
                  // Telegram connection picker
                  if (telegramConnections.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.send),
                      title: Text(
                        telegramConnectionUuid != null
                            ? (telegramConnections
                                      .where(
                                        (c) => c.uuid == telegramConnectionUuid,
                                      )
                                      .firstOrNull
                                      ?.name ??
                                  l10n.telegramChosen)
                            : l10n.noTelegram,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButton<String?>(
                            value: telegramConnectionUuid,
                            hint: Text(l10n.choose),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(l10n.none),
                              ),
                              ...telegramConnections.map(
                                (c) => DropdownMenuItem(
                                  value: c.uuid,
                                  child: Text(c.name),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setS(() => telegramConnectionUuid = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.notesInCalendar),
                    value: includeNotes,
                    onChanged: (v) => setS(() => includeNotes = v ?? true),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.personsInCalendar),
                    value: includePersons,
                    onChanged: (v) => setS(() => includePersons = v ?? true),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.activitiesInCalendar),
                    value: includeActivities,
                    onChanged: (v) => setS(() => includeActivities = v ?? true),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.autoGroup),
                    subtitle: Text(l10n.autoGroupSubtitle),
                    value: isAutoGroup,
                    onChanged: (v) => setS(() => isAutoGroup = v ?? false),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.type),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: PlaceType.values.map((t) {
                      final selected = placeType == t;
                      return ChoiceChip(
                        avatar: Icon(
                          t.icon,
                          size: 16,
                          color: selected ? Colors.white : t.dotColor,
                        ),
                        label: Text(t.label),
                        selected: selected,
                        selectedColor: t.dotColor,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : null,
                        ),
                        onSelected: (_) => setS(() => placeType = t),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final group = PlaceGroup(
                    uuid: existing?.uuid,
                    name: name,
                    calendarId: calendarId,
                    telegramConnectionUuid: telegramConnectionUuid,
                    includeNotes: includeNotes,
                    includePersons: includePersons,
                    includeActivities: includeActivities,
                    isAutoGroup: isAutoGroup,
                    placeType: placeType,
                  );
                  Navigator.pop(ctx, group);
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _pickCalendar(BuildContext ctx) async {
    final granted = await CalendarService.instance.requestPermissions();
    if (!granted) return null;

    final calendars = await CalendarService.instance.loadCalendars();
    if (!ctx.mounted) return null;

    return showDialog<String>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text(AppLocalizations.of(dCtx)!.pickCalendar),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: calendars
                .map(
                  (c) => ListTile(
                    leading: const Icon(Icons.calendar_month),
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
                      if (g.calendarId != null) ...const [
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
