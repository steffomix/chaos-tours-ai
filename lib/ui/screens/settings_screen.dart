import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/aktivitaet.dart';
import '../../models/place_group.dart';
import '../../models/saved_place.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../utils/permission_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _deviceId;
  late int _gpsInterval;
  late int _stayDetection;
  late int _autoPlaceTime;
  late double _defaultRadius;
  late bool _autoCreatePlaces;
  String? _autoPlaceGroupUuid;
  String? _defaultPlaceGroupUuid;
  late int _gpsSmoothingPoints;
  late bool _showTrackingPoints;
  late double _trackingPointRadius;
  late int _timelineHistoryDays;
  late String _searchCountry;
  final TextEditingController _searchCountryCtrl = TextEditingController();
  late int _schedulerColorRange;
  Set<String> _schedulerGroupIds = {};
  List<PlaceGroup> _groups = [];

  // Network info for display (used by SyncSourcesScreen)

  // Aktivitaet management
  List<Aktivitaet> _aktivitaeten = [];
  Aktivitaet? _activeAktivitaet;

  @override
  void dispose() {
    _searchCountryCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _deviceId = s.deviceId;
    _gpsInterval = s.gpsIntervalSeconds;
    _stayDetection = s.stayDetectionSeconds;
    _autoPlaceTime = s.autoPlaceSeconds;
    _defaultRadius = s.defaultRadiusMeters;
    _autoCreatePlaces = s.autoCreatePlaces;
    _autoPlaceGroupUuid = s.autoPlaceGroupUuid;
    _defaultPlaceGroupUuid = s.defaultPlaceGroupUuid;
    _gpsSmoothingPoints = s.gpsSmoothingPoints;
    _showTrackingPoints = s.showTrackingPoints;
    _trackingPointRadius = s.trackingPointRadius;
    _timelineHistoryDays = s.timelineHistoryDays;
    _searchCountry = s.searchCountry;
    _searchCountryCtrl.text = _searchCountry;
    _schedulerColorRange = s.schedulerColorRange;
    _schedulerGroupIds = Set<String>.from(s.schedulerGroupUuidList);
    _loadGroups();
    _loadAktivitaeten();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseService.instance.loadAllPlaceGroups();
    if (mounted) setState(() => _groups = groups);
  }

  Future<void> _loadAktivitaeten() async {
    final list = await DatabaseService.instance.loadAllAktivitaeten();
    final activeUuid = SettingsService.instance.activeAktivitaetUuid;
    if (mounted) {
      setState(() {
        _aktivitaeten = list;
        _activeAktivitaet =
            list.where((a) => a.uuid == activeUuid).firstOrNull ??
            list.firstOrNull;
      });
    }
  }

  Future<void> _saveAll() async {
    final s = SettingsService.instance;
    s.deviceId = _deviceId;
    s.gpsIntervalSeconds = _gpsInterval;
    s.stayDetectionSeconds = _stayDetection;
    s.autoPlaceSeconds = _autoPlaceTime;
    s.defaultRadiusMeters = _defaultRadius;
    s.autoCreatePlaces = _autoCreatePlaces;
    s.autoPlaceGroupUuid = _autoPlaceGroupUuid;
    s.defaultPlaceGroupUuid = _defaultPlaceGroupUuid;
    s.gpsSmoothingPoints = _gpsSmoothingPoints;
    s.showTrackingPoints = _showTrackingPoints;
    s.trackingPointRadius = _trackingPointRadius;
    s.timelineHistoryDays = _timelineHistoryDays;
    s.searchCountry = _searchCountry;
    s.schedulerColorRange = _schedulerColorRange;
    s.schedulerGroupIds = _schedulerGroupIds.join(',');

    // Persist settings back into the active Aktivitaet.
    final a = _activeAktivitaet;
    if (a != null) {
      await DatabaseService.instance.updateAktivitaet(
        s.snapshotAsAktivitaet(uuid: a.uuid, name: a.name),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveAll();
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Aktivität ─────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.bolt),
            title: Text(_activeAktivitaet?.name ?? l10n.noActivity),
            subtitle: Text(l10n.activityCount(_aktivitaeten.length)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.tooltipRename,
                  onPressed: _activeAktivitaet == null
                      ? null
                      : () => _renameAktivitaet(_activeAktivitaet!),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: l10n.tooltipSwitchCreate,
                  onPressed: _showAktivitaetenPicker,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 0, 0),
            child: Text(
              l10n.deviceId,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 0, 8),
            child: Text(_deviceId, style: const TextStyle(fontSize: 12)),
          ),
          const Divider(),
          // ── Verwaltung ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.sectionManagement,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(l10n.placeGroups),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/place-groups'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: Text(l10n.persons),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/persons'),
          ),
          ListTile(
            leading: const Icon(Icons.work_outline),
            title: Text(l10n.activities),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/activities'),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: Text(l10n.databaseDump),
            subtitle: Text(l10n.databaseDumpSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/database-dump'),
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(l10n.syncSources),
            subtitle: Text(l10n.syncSourcesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/sync-sources'),
          ),
          ListTile(
            leading: const Icon(Icons.send),
            title: Text(l10n.telegramConnections),
            subtitle: Text(l10n.telegramConnectionsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/telegram-connections'),
          ),
          const Divider(),
          // ── Adresssuche ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.sectionAddressSearch,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(l10n.defaultCountry),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCountryCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.defaultCountryHint,
                    isDense: true,
                  ),
                  onChanged: (v) => _searchCountry = v,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.defaultCountrySubtitle,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(),
          // ── Planer ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.sectionPlanner,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: Text(l10n.colorRange(_schedulerColorRange)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _schedulerColorRange.toDouble(),
                  min: 1,
                  max: 90,
                  divisions: 89,
                  label: '$_schedulerColorRange',
                  onChanged: (v) =>
                      setState(() => _schedulerColorRange = v.round()),
                ),
                Text(
                  l10n.colorRangeHint(_schedulerColorRange),
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(),
          // ── Tracking Settings ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.sectionTracking,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.autoCreatePlaces),
            subtitle: Text(l10n.autoCreatePlacesSubtitle),
            value: _autoCreatePlaces,
            onChanged: (v) => setState(() => _autoCreatePlaces = v),
          ),
          if (_autoCreatePlaces)
            ListTile(
              title: Text(l10n.autoPlaceGroup),
              trailing: DropdownButton<String?>(
                value: _autoPlaceGroupUuid == null
                    ? null
                    : (_groups.any((g) => g.uuid == _autoPlaceGroupUuid)
                          ? _autoPlaceGroupUuid
                          : null),
                hint: Text(l10n.none),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.none)),
                  ..._groups.map(
                    (g) => DropdownMenuItem(value: g.uuid, child: Text(g.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _autoPlaceGroupUuid = v),
              ),
            ),
          ListTile(
            title: Text(l10n.defaultPlaceGroup),
            subtitle: Text(l10n.defaultPlaceGroupSubtitle),
            trailing: DropdownButton<String?>(
              value: _defaultPlaceGroupUuid == null
                  ? null
                  : (_groups.any((g) => g.uuid == _defaultPlaceGroupUuid)
                        ? _defaultPlaceGroupUuid
                        : null),
              hint: Text(l10n.none),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.none)),
                ..._groups.map(
                  (g) => DropdownMenuItem(value: g.uuid, child: Text(g.name)),
                ),
              ],
              onChanged: (v) => setState(() => _defaultPlaceGroupUuid = v),
            ),
          ),
          ListTile(
            title: Text(l10n.shownGroups),
            subtitle: _groups.isEmpty
                ? Text(l10n.noGroupsAvailable)
                : Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: Text(l10n.all),
                        selected: _schedulerGroupIds.isEmpty,
                        onSelected: (_) =>
                            setState(() => _schedulerGroupIds.clear()),
                      ),
                      ..._groups.map(
                        (g) => FilterChip(
                          avatar: Icon(
                            g.placeType.icon,
                            size: 14,
                            color: g.placeType.dotColor,
                          ),
                          label: Text(g.name),
                          selected: _schedulerGroupIds.contains(g.uuid),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _schedulerGroupIds.add(g.uuid);
                              } else {
                                _schedulerGroupIds.remove(g.uuid);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          ListTile(
            title: Text(l10n.gpsInterval(_gpsInterval)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _gpsInterval.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  label: '${_gpsInterval}s',
                  onChanged: (v) => setState(() => _gpsInterval = v.round()),
                ),
                Text(
                  l10n.gpsIntervalHint,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(
              l10n.gpsSmoothing(
                _gpsSmoothingPoints == 1
                    ? l10n.gpsSmoothingDisabled
                    : l10n.gpsSmoothingPoints(_gpsSmoothingPoints),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _gpsSmoothingPoints.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: _gpsSmoothingPoints == 1
                      ? 'aus'
                      : '$_gpsSmoothingPoints',
                  onChanged: (v) =>
                      setState(() => _gpsSmoothingPoints = v.round()),
                ),
                Text(
                  l10n.gpsSmoothingHint,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(l10n.stayDetection((_stayDetection / 60).round())),
            subtitle: Slider(
              value: _stayDetection.toDouble(),
              min: 60,
              max: 600,
              divisions: 18,
              label: '${(_stayDetection / 60).toStringAsFixed(0)} min',
              onChanged: (v) => setState(() => _stayDetection = v.round()),
            ),
          ),
          ListTile(
            title: Text(l10n.autoPlaceTime((_autoPlaceTime / 60).round())),
            subtitle: Slider(
              value: _autoPlaceTime.toDouble(),
              min: 300,
              max: 3600,
              divisions: 33,
              label: '${(_autoPlaceTime / 60).toStringAsFixed(0)} min',
              onChanged: (v) => setState(() => _autoPlaceTime = v.round()),
            ),
          ),
          ListTile(
            title: Text(l10n.defaultRadius(_defaultRadius.toStringAsFixed(0))),
            subtitle: Slider(
              value: _defaultRadius,
              min: 10,
              max: 500,
              divisions: 49,
              label: '${_defaultRadius.toStringAsFixed(0)} m',
              onChanged: (v) => setState(() => _defaultRadius = v),
            ),
          ),
          const Divider(),
          // ── Kartendarstellung ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.sectionMapDisplay,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.showGpsPoints),
            subtitle: Text(l10n.showGpsPointsSubtitle),
            value: _showTrackingPoints,
            onChanged: (v) => setState(() => _showTrackingPoints = v),
          ),
          if (_showTrackingPoints)
            ListTile(
              title: Text(
                l10n.pointSize(_trackingPointRadius.toStringAsFixed(1)),
              ),
              subtitle: Slider(
                value: _trackingPointRadius,
                min: 1,
                max: 20,
                divisions: 19,
                label: '${_trackingPointRadius.toStringAsFixed(1)} m',
                onChanged: (v) => setState(() => _trackingPointRadius = v),
              ),
            ),
          ListTile(
            title: Text(
              l10n.visitHistory(
                _timelineHistoryDays == 1
                    ? l10n.visitHistoryDay(_timelineHistoryDays)
                    : l10n.visitHistoryDays(_timelineHistoryDays),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _timelineHistoryDays.toDouble(),
                  min: 7,
                  max: 90,
                  //divisions: 29,
                  label: '$_timelineHistoryDays',
                  onChanged: (v) =>
                      setState(() => _timelineHistoryDays = v.round()),
                ),
                Text(
                  l10n.visitHistoryHint,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(),
          // ── Berechtigungen ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.sectionPermissions,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(l10n.locationPermission),
            subtitle: Text(l10n.locationPermissionSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await PermissionHelper.instance
                  .requestLocationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted ? l10n.locationGranted : l10n.locationDenied,
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_searching),
            title: Text(l10n.backgroundLocation),
            subtitle: Text(l10n.backgroundLocationSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await PermissionHelper.instance
                  .requestBackgroundLocationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted
                          ? l10n.backgroundLocationGranted
                          : l10n.backgroundLocationDenied,
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(l10n.notifications),
            subtitle: Text(l10n.notificationsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await PermissionHelper.instance
                  .requestNotificationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted
                          ? l10n.notificationsGranted
                          : l10n.notificationsDenied,
                    ),
                  ),
                );
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.calendar_today),
            title: Text(l10n.calendarSync),
            subtitle: Text(l10n.calendarSyncSubtitle),
            value: SettingsService.instance.calendarEnabled,
            onChanged: (v) =>
                setState(() => SettingsService.instance.calendarEnabled = v),
          ),
          if (SettingsService.instance.calendarEnabled)
            ListTile(
              leading: const Icon(Icons.lock_open_outlined),
              title: Text(l10n.calendarPermission),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final granted = await PermissionHelper.instance
                    .requestCalendarPermission();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        granted ? l10n.calendarGranted : l10n.calendarDenied,
                      ),
                    ),
                  );
                }
              },
            ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Chaos Tours'),
            subtitle: Text('Version 2.0.0'),
          ),
          // ── Aktivität löschen ─────────────────────────────────────────
          if (_aktivitaeten.length > 1 && _activeAktivitaet != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(
                l10n.deleteActivityLabel(_activeAktivitaet!.name),
                style: const TextStyle(color: Colors.red),
              ),
              subtitle: Text(l10n.deleteActivity),
              onTap: _deleteCurrentAktivitaet,
            ),
          ],
        ],
      ),
    );
  }

  // ── Aktivitaet helpers ────────────────────────────────────────────────────

  void _showAktivitaetenPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            final l10n = AppLocalizations.of(ctx2)!;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt),
                        const SizedBox(width: 8),
                        Text(
                          l10n.pickActivity,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ..._aktivitaeten.map((a) {
                    final isActive = a.uuid == _activeAktivitaet?.uuid;
                    return ListTile(
                      leading: Icon(
                        isActive
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: isActive
                            ? Theme.of(ctx2).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        a.name,
                        style: isActive
                            ? TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(ctx2).colorScheme.primary,
                              )
                            : null,
                      ),
                      onTap: () async {
                        Navigator.pop(ctx2);
                        await _switchAktivitaet(a);
                      },
                    );
                  }),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline),
                    title: Text(l10n.newActivityCreate),
                    onTap: () async {
                      Navigator.pop(ctx2);
                      await _createNewAktivitaet();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _switchAktivitaet(Aktivitaet a) async {
    // Save current settings to the old active Aktivitaet first.
    await _saveAll();
    // Load new Aktivitaet and apply.
    SettingsService.instance.applyAktivitaet(a);
    if (mounted) {
      setState(() {
        _activeAktivitaet = a;
        _gpsInterval = a.gpsIntervalSeconds;
        _stayDetection = a.stayDetectionSeconds;
        _autoPlaceTime = a.autoPlaceSeconds;
        _defaultRadius = a.defaultRadiusMeters;
        _autoCreatePlaces = a.autoCreatePlaces;
        _autoPlaceGroupUuid = a.autoPlaceGroupUuid;
        _defaultPlaceGroupUuid = a.defaultPlaceGroupUuid;
      });
    }
  }

  Future<void> _createNewAktivitaet() async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(
      text: '${l10n.sectionActivity} ${_aktivitaeten.length + 1}',
    );
    final deviceIdCtrl = TextEditingController(text: _deviceId);
    // Offer to copy from an existing one as template.
    Aktivitaet template = _activeAktivitaet ?? Aktivitaet(name: '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          //title: Text(l10n.newActivityLabel),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.newActivityLabel),
                autofocus: true,
              ),
              if (_aktivitaeten.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.copySettingsFrom,
                  style: const TextStyle(fontSize: 13),
                ),
                StatefulBuilder(
                  builder: (ctx2, setInner) => DropdownButton<Aktivitaet>(
                    isExpanded: true,
                    value: template,
                    items: _aktivitaeten
                        .map(
                          (a) =>
                              DropdownMenuItem(value: a, child: Text(a.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setInner(() => template = v);
                    },
                  ),
                ),
              ],

              TextField(
                controller: deviceIdCtrl,
                decoration: InputDecoration(labelText: l10n.deviceId),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    final deviceId = deviceIdCtrl.text.trim();
    if (name.isEmpty || deviceId.isEmpty) return;

    final newA = template.copyWith(name: name, uuid: '', deviceId: deviceId);
    final id = await DatabaseService.instance.insertAktivitaet(newA);
    final created = await DatabaseService.instance.loadAktivitaet(id);
    if (created != null) await _switchAktivitaet(created);
    await _loadAktivitaeten();
    await _loadGroups();
  }

  Future<void> _renameAktivitaet(Aktivitaet a) async {
    final ctrl = TextEditingController(text: a.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.renameActivity),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(labelText: l10n.name),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final name = ctrl.text.trim();
    if (name.isEmpty || name == a.name) return;
    final updated = a.copyWith(name: name);
    await DatabaseService.instance.updateAktivitaet(updated);
    await _loadAktivitaeten();
  }

  Future<void> _deleteCurrentAktivitaet() async {
    final a = _activeAktivitaet;
    if (a == null || _aktivitaeten.length <= 1) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.deleteActivityTitle),
          content: Text(l10n.deleteActivityContent(a.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                l10n.delete,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    // Switch to another Aktivitaet before deleting.
    final next = _aktivitaeten.firstWhere((x) => x.uuid != a.uuid);
    await _switchAktivitaet(next);
    await DatabaseService.instance.deleteAktivitaet(a.uuid);
    await _loadAktivitaeten();

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.activityDeleted(a.name))));
    }
  }
}
