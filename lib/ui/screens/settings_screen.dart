import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:uuid/uuid.dart';

import 'dart:math';

import '../../models/aktivitaet.dart';
import '../../models/place_group.dart';
import '../../models/saved_place.dart';
import '../../models/trusted_source.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../utils/permission_helper.dart';
import '../../utils/random_data_generator.dart';

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
  String? _syncSourcePlaceGroupUuid;
  late int _gpsSmoothingPoints;
  late bool _showTrackingPoints;
  late double _trackingPointRadius;
  late int _timelineHistoryDays;
  late String _searchCountry;
  final TextEditingController _searchCountryCtrl = TextEditingController();
  late bool _addressOnAutoCreate;
  late bool _addressOnManualCreate;
  late bool _addressOnInterval;
  final TextEditingController _nominatimUserAgentCtrl = TextEditingController();
  late int _schedulerColorRange;
  Set<String> _schedulerGroupIds = {};
  List<PlaceGroup> _groups = [];
  late int _photoMaxWidth;
  late int _photoMaxHeight;
  late int _photoImageQuality;

  // P2P Messenger / mesh sync
  late bool _messengerEnabled;
  late bool _createPlaceOnSyncOpportunity;
  late bool _syncPhotosEnabled;
  late int _photoSyncMaxBytes;
  late NodeScanMode _nodeScanMode;
  late int _nodeScanIntervalPerGps;

  // Falls du ein StatefulWidget nutzt, definiere den Generator in deinem State:
  final RandomDataGenerator _generator = RandomDataGenerator();
  // Network info for display (used by SyncSourcesScreen)
  // Aktivitaet management
  List<Aktivitaet> _aktivitaeten = [];
  Aktivitaet? _activeAktivitaet;

  @override
  void dispose() {
    _searchCountryCtrl.dispose();
    _nominatimUserAgentCtrl.dispose();
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
    _syncSourcePlaceGroupUuid = s.syncSourcePlaceGroupUuid;
    _gpsSmoothingPoints = s.gpsSmoothingPoints;
    _showTrackingPoints = s.showTrackingPoints;
    _trackingPointRadius = s.trackingPointRadius;
    _timelineHistoryDays = s.timelineHistoryDays;
    _searchCountry = s.searchCountry;
    _searchCountryCtrl.text = _searchCountry;
    _addressOnAutoCreate = s.addressOnAutoCreate;
    _addressOnManualCreate = s.addressOnManualCreate;
    _addressOnInterval = s.addressOnInterval;
    _nominatimUserAgentCtrl.text = s.nominatimUserAgent;
    _schedulerColorRange = s.schedulerColorRange;
    _schedulerGroupIds = Set<String>.from(s.schedulerGroupUuidList);
    _photoMaxWidth = s.photoMaxWidth;
    _photoMaxHeight = s.photoMaxHeight;
    _photoImageQuality = s.photoImageQuality;
    _messengerEnabled = s.messengerEnabled;
    _createPlaceOnSyncOpportunity = s.createPlaceOnSyncOpportunity;
    _syncPhotosEnabled = s.syncPhotosEnabled;
    _photoSyncMaxBytes = s.photoSyncMaxBytes;
    _nodeScanMode = s.nodeScanMode;
    _nodeScanIntervalPerGps = s.nodeScanIntervalPerGps;
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
    bool gpsInterfalChanged = s.gpsIntervalSeconds != _gpsInterval;
    s.deviceId = _deviceId;
    s.gpsIntervalSeconds = _gpsInterval;
    s.stayDetectionSeconds = _stayDetection;
    s.autoPlaceSeconds = _autoPlaceTime;
    s.defaultRadiusMeters = _defaultRadius;
    s.autoCreatePlaces = _autoCreatePlaces;
    s.autoPlaceGroupUuid = _autoPlaceGroupUuid;
    s.defaultPlaceGroupUuid = _defaultPlaceGroupUuid;
    s.syncSourcePlaceGroupUuid = _syncSourcePlaceGroupUuid;
    s.gpsSmoothingPoints = _gpsSmoothingPoints;
    s.showTrackingPoints = _showTrackingPoints;
    s.trackingPointRadius = _trackingPointRadius;
    s.timelineHistoryDays = _timelineHistoryDays;
    s.searchCountry = _searchCountry;
    s.addressOnAutoCreate = _addressOnAutoCreate;
    s.addressOnManualCreate = _addressOnManualCreate;
    s.addressOnInterval = _addressOnInterval;
    s.nominatimUserAgent = _nominatimUserAgentCtrl.text;
    s.schedulerColorRange = _schedulerColorRange;
    s.schedulerGroupIds = _schedulerGroupIds.join(',');
    s.photoMaxWidth = _photoMaxWidth;
    s.photoMaxHeight = _photoMaxHeight;
    s.photoImageQuality = _photoImageQuality;
    s.messengerEnabled = _messengerEnabled;
    s.createPlaceOnSyncOpportunity = _createPlaceOnSyncOpportunity;
    s.syncPhotosEnabled = _syncPhotosEnabled;
    s.photoSyncMaxBytes = _photoSyncMaxBytes;
    s.nodeScanMode = _nodeScanMode;
    s.nodeScanIntervalPerGps = _nodeScanIntervalPerGps;
    // notify foreground service about new settings
    if (gpsInterfalChanged && (Platform.isAndroid || Platform.isIOS)) {
      await FlutterForegroundTask.updateService(
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(
            s.gpsIntervalSeconds * 1000,
          ),
        ),
      );
    }
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
      body: SafeArea(
        child: ListView(
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
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.deviceId),
              subtitle: Text(_deviceId),
              onTap: () {
                Clipboard.setData(ClipboardData(text: _deviceId));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.deviceIdCopied)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: Text(l10n.trustedSourcesTitle),
              subtitle: Text(l10n.trustedSourcesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/trusted-sources'),
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
              onTap: () =>
                  Navigator.pushNamed(context, '/telegram-connections'),
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
            CheckboxListTile(
              secondary: const Icon(Icons.auto_awesome),
              title: Text(l10n.addressOnAutoCreateTitle),
              subtitle: Text(l10n.addressOnAutoCreateSubtitle),
              value: _addressOnAutoCreate,
              onChanged: (v) =>
                  setState(() => _addressOnAutoCreate = v ?? true),
            ),
            CheckboxListTile(
              secondary: const Icon(Icons.touch_app),
              title: Text(l10n.addressOnManualCreateTitle),
              subtitle: Text(l10n.addressOnManualCreateSubtitle),
              value: _addressOnManualCreate,
              onChanged: (v) =>
                  setState(() => _addressOnManualCreate = v ?? true),
            ),
            CheckboxListTile(
              secondary: const Icon(Icons.gps_fixed),
              title: Text(l10n.addressOnIntervalTitle),
              subtitle: Text(l10n.addressOnIntervalSubtitle),
              value: _addressOnInterval,
              onChanged: (v) => setState(() => _addressOnInterval = v ?? false),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(l10n.nominatimUserAgent),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nominatimUserAgentCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.nominatimUserAgentHint,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.nominatimUserAgentSubtitle,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.autoCreatePlacesMessengerNote,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
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
                      (g) =>
                          DropdownMenuItem(value: g.uuid, child: Text(g.name)),
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
              title: Text(l10n.syncPlaceGroup),
              subtitle: Text(l10n.syncPlaceGroupSubtitle),
              trailing: DropdownButton<String?>(
                value: _syncSourcePlaceGroupUuid == null
                    ? null
                    : (_groups.any((g) => g.uuid == _syncSourcePlaceGroupUuid)
                          ? _syncSourcePlaceGroupUuid
                          : null),
                hint: Text(l10n.none),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.none)),
                  ..._groups.map(
                    (g) => DropdownMenuItem(value: g.uuid, child: Text(g.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _syncSourcePlaceGroupUuid = v),
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
              title: Text(
                l10n.defaultRadius(_defaultRadius.toStringAsFixed(0)),
              ),
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

            /* 
            // ── P2P Messenger / Mesh-Sync ─────────────────────────────────
            ElevatedButton.icon(
              onPressed: () async {
                final gps = await LocationService.instance.getCurrentPosition();
                if (gps == null) {
                  MeshSyncService.log.error =
                      'Could not get GPS position for sync opportunity.';
                  return;
                }
                MeshSyncService.instance.onSyncOpportunity(
                  lat: gps.latitude,
                  lng: gps.longitude,
                );
              },
              icon: const Icon(Icons.sync),
              label: Text('Jetzt Sync-Möglichkeit auslösen'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: ValueListenableBuilder<String>(
                valueListenable: MeshSyncService.log,
                builder: (context, progressText, child) {
                  return Text(
                    progressText,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.sectionP2pMessenger,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SwitchListTile(
              title: Text(l10n.messengerEnable),
              subtitle: Text(l10n.messengerEnableSubtitle),
              value: _messengerEnabled,
              onChanged: (v) => setState(() => _messengerEnabled = v),
            ),
            if (_messengerEnabled) ...[
              SwitchListTile(
                title: Text(l10n.createPlaceOnSync),
                subtitle: Text(l10n.createPlaceOnSyncSubtitle),
                value: _createPlaceOnSyncOpportunity,
                onChanged: (v) =>
                    setState(() => _createPlaceOnSyncOpportunity = v),
              ),
              SwitchListTile(
                title: Text(l10n.syncPhotos),
                subtitle: Text(l10n.syncPhotosSubtitle),
                value: _syncPhotosEnabled,
                onChanged: (v) => setState(() => _syncPhotosEnabled = v),
              ),
              if (_syncPhotosEnabled)
                ListTile(
                  title: Text(
                    _photoSyncMaxBytes == 0
                        ? l10n.photoSizeLimitUnlimited
                        : l10n.photoSizeLimitKib(
                            (_photoSyncMaxBytes / 1024).round(),
                          ),
                  ),
                  subtitle: Slider(
                    value: (_photoSyncMaxBytes / 1024)
                        .clamp(0, 4096)
                        .toDouble(),
                    min: 0,
                    max: 4096,
                    divisions: 32,
                    label: _photoSyncMaxBytes == 0
                        ? l10n.unlimited
                        : '${(_photoSyncMaxBytes / 1024).round()} KiB',
                    onChanged: (v) =>
                        setState(() => _photoSyncMaxBytes = (v.round() * 1024)),
                  ),
                ),
              ListTile(
                title: Text(l10n.nodeScanModeLabel),
                trailing: DropdownButton<NodeScanMode>(
                  value: _nodeScanMode,
                  items: [
                    DropdownMenuItem(
                      value: NodeScanMode.onHalt,
                      child: Text(l10n.nodeScanOnHalt),
                    ),
                    DropdownMenuItem(
                      value: NodeScanMode.perGpsInterval,
                      child: Text(l10n.nodeScanPerGps),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _nodeScanMode = v ?? NodeScanMode.onHalt),
                ),
              ),
              if (_nodeScanMode == NodeScanMode.perGpsInterval)
                ListTile(
                  title: Text(l10n.nodeScanEvery(_nodeScanIntervalPerGps)),
                  subtitle: Slider(
                    value: _nodeScanIntervalPerGps.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$_nodeScanIntervalPerGps',
                    onChanged: (v) =>
                        setState(() => _nodeScanIntervalPerGps = v.round()),
                  ),
                ),
            ], */
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
            // ── Fotos ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.sectionPhotos,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: Text(l10n.photoMaxWidth(_photoMaxWidth)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Slider(
                    value: _photoMaxWidth.toDouble(),
                    min: 0,
                    max: 4096,
                    divisions: 64,
                    label: _photoMaxWidth == 0 ? '∞' : '$_photoMaxWidth',
                    onChanged: (v) =>
                        setState(() => _photoMaxWidth = (v / 64).round() * 64),
                  ),
                  Text(
                    l10n.photoMaxDimensionSubtitle,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text(l10n.photoMaxHeight(_photoMaxHeight)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Slider(
                    value: _photoMaxHeight.toDouble(),
                    min: 0,
                    max: 4096,
                    divisions: 64,
                    label: _photoMaxHeight == 0 ? '∞' : '$_photoMaxHeight',
                    onChanged: (v) =>
                        setState(() => _photoMaxHeight = (v / 64).round() * 64),
                  ),
                  Text(
                    l10n.photoMaxDimensionSubtitle,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text(l10n.photoImageQuality(_photoImageQuality)),
              subtitle: Slider(
                value: _photoImageQuality.toDouble(),
                min: 10,
                max: 100,
                divisions: 18,
                label: '$_photoImageQuality %',
                onChanged: (v) =>
                    setState(() => _photoImageQuality = v.round()),
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
            ..._buildDevToolsSection(l10n),
          ],
        ),
      ),
    );
  }

  // ── Aktivitaet helpers ────────────────────────────────────────────────────

  /// Builds the potentially destructive developer tools, always rendered at the
  /// very bottom of the settings list. The tools are only visible while unlocked
  /// (for one hour after solving the type-in challenge).
  List<Widget> _buildDevToolsSection(AppLocalizations l10n) {
    final unlocked = SettingsService.instance.devToolsUnlocked;

    if (!unlocked || kDebugMode == true) {
      return [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.devToolsSectionTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.devToolsWarning,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            icon: const Icon(Icons.lock_open),
            label: Text(l10n.devToolsUnlockButton),
            onPressed: _startDevToolsChallenge,
          ),
        ),
      ];
    }

    final until = DateTime.fromMillisecondsSinceEpoch(
      SettingsService.instance.devToolsUnlockedUntilMs,
    );
    final untilText =
        '${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}';

    return [
      const Divider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          l10n.devToolsSectionTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Text(
          l10n.devToolsUnlockedUntil(untilText),
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.storage),
        title: Text(l10n.databaseExplorerButton),
        onTap: () => Navigator.pushNamed(context, '/database-explorer'),
      ),
      ListTile(
        leading: const Icon(Icons.tune),
        title: Text(l10n.sharedPrefsExplorerButton),
        onTap: () => Navigator.pushNamed(context, '/shared-prefs-explorer'),
      ),
      ListTile(
        leading: const Icon(Icons.shuffle),
        title: Text(l10n.generateRandomData),
        onTap: () async {
          await _generator.generateRandomData();
        },
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: ValueListenableBuilder<String>(
          valueListenable: _generator.progressNotifier,
          builder: (context, progressText, child) {
            return Text(
              progressText,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            );
          },
        ),
      ),
      ListTile(
        leading: const Icon(Icons.lock_outline, color: Colors.red),
        title: Text(
          l10n.devToolsRelock,
          style: const TextStyle(color: Colors.red),
        ),
        onTap: () {
          SettingsService.instance.devToolsUnlockedUntilMs = 0;
          setState(() {});
        },
      ),
    ];
  }

  /// Generates a random 8-character letter code the user must type correctly to
  /// unlock the developer tools for one hour.
  Future<void> _startDevToolsChallenge() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rnd = Random.secure();
    final code = List.generate(
      8,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
    final controller = TextEditingController();

    final success = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final l10n = AppLocalizations.of(dialogCtx)!;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final input = controller.text.trim().toUpperCase();
            final matches = input == code;
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.devToolsSectionTitle)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.devToolsWarning,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.devToolsChallengeInstruction),
                  const SizedBox(height: 8),
                  SelectionContainer.disabled(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: l10n.devToolsChallengeHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: matches ? () => Navigator.pop(ctx, true) : null,
                  child: Text(l10n.ok),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (success == true) {
      SettingsService.instance.devToolsUnlockedUntilMs = DateTime.now()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      if (mounted) {
        setState(() {});
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.devToolsUnlockSuccess)));
      }
    }
  }

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
        _deviceId = a.deviceId;
        _gpsInterval = a.gpsIntervalSeconds;
        _stayDetection = a.stayDetectionSeconds;
        _autoPlaceTime = a.autoPlaceSeconds;
        _defaultRadius = a.defaultRadiusMeters;
        _autoCreatePlaces = a.autoCreatePlaces;
        _autoPlaceGroupUuid = a.autoPlaceGroupUuid;
        _defaultPlaceGroupUuid = a.defaultPlaceGroupUuid;
        _syncSourcePlaceGroupUuid = a.syncSourcePlaceGroupUuid;
      });
    }
  }

  Future<void> _createNewAktivitaet() async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(
      text: '${l10n.sectionActivity} ${_aktivitaeten.length + 1}',
    );
    final deviceNameCtrl = TextEditingController();
    // Offer to copy from an existing one as template.
    Aktivitaet template = _activeAktivitaet ?? Aktivitaet(name: '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
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
              const SizedBox(height: 12),
              TextField(
                controller: deviceNameCtrl,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: l10n.deviceNameLabel,
                  hintText: l10n.deviceNameHint,
                  helperText: l10n.deviceNameLengthHint,
                ),
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
    final deviceNameInput = deviceNameCtrl.text.trim();
    if (name.isEmpty) return;
    if (deviceNameInput.length < 3 || deviceNameInput.length > 20) return;

    const uuid = Uuid();
    final deviceId = '$deviceNameInput@${uuid.v4()}';
    final newA = template.copyWith(name: name, uuid: '', deviceId: deviceId);
    final db = DatabaseService.instance;
    final id = await db.insertAktivitaet(newA);
    // set the new deviceId as trusted source.
    await db.refreshTrustedSources();
    await db.upsertTrustedSource(
      TrustedSource(deviceId: deviceId, trusted: true),
    );
    final created = await db.loadAktivitaet(id);

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
