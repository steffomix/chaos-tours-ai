import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../../models/place_group.dart';
import '../../../models/saved_place.dart';
import '../../../services/database_service.dart';
import '../../../services/settings_service.dart';
import 'place_group_edit_screen.dart';

class PlaceGroupsScreen extends StatefulWidget {
  const PlaceGroupsScreen({super.key});

  @override
  State<PlaceGroupsScreen> createState() => _PlaceGroupsScreenState();
}

class _PlaceGroupsScreenState extends State<PlaceGroupsScreen> {
  static const int _chunkSize = 20;

  final ScrollController _scrollCtrl = ScrollController();
  List<PlaceGroup> _allGroups = [];
  int _displayCount = _chunkSize;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        _displayCount < _allGroups.length) {
      setState(() => _displayCount += _chunkSize);
    }
  }

  Future<void> _load() async {
    final groups = await DatabaseService.instance.loadAllPlaceGroups();
    if (mounted) {
      setState(() {
        _allGroups = groups;
        _displayCount = _chunkSize;
      });
    }
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
        builder: (_) => PlaceGroupEditScreen(
          existing: existing,
          telegramConnections: telegramConnections,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayed = _allGroups.take(_displayCount).toList();
    final hasMore = _displayCount < _allGroups.length;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.placeGroupsTitle)),
      body: _allGroups.isEmpty
          ? Center(child: Text(l10n.noGroupsYet))
          : ListView.builder(
              controller: _scrollCtrl,
              itemCount: displayed.length + (hasMore ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i >= displayed.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final g = displayed[i];
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
