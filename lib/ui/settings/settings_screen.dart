import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'dart:math';

import '../../models/virtual_device.dart';
import '../../models/place_group.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../utils/custom_icons.dart';
import '../../utils/permission_helper.dart';
import '../../utils/random_data_generator.dart';
import '../../utils/unified_widget.dart';

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
  List<PlaceGroup> _groups = [];
  late int _photoMaxWidth;
  late int _photoMaxHeight;
  late int _photoImageQuality;
  late int _placeDetailPhotoCount;

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
  // VirtualDevice management
  List<VirtualDevice> _virtualDevices = [];
  VirtualDevice? _activeVirtualDevice;

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
    _photoMaxWidth = s.photoMaxWidth;
    _photoMaxHeight = s.photoMaxHeight;
    _photoImageQuality = s.photoImageQuality;
    _placeDetailPhotoCount = s.placeDetailPhotoCount;
    _messengerEnabled = s.messengerEnabled;
    _createPlaceOnSyncOpportunity = s.createPlaceOnSyncOpportunity;
    _syncPhotosEnabled = s.syncPhotosEnabled;
    _photoSyncMaxBytes = s.photoSyncMaxBytes;
    _nodeScanMode = s.nodeScanMode;
    _nodeScanIntervalPerGps = s.nodeScanIntervalPerGps;
    _loadGroups();
    _loadVirtualDevices();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseService.instance.loadAllPlaceGroups();
    if (mounted) setState(() => _groups = groups);
  }

  Future<void> _loadVirtualDevices() async {
    final list = await DatabaseService.instance.loadAllVirtualDevices();
    final activeUuid = SettingsService.instance.activeVirtualDeviceUuid;
    if (mounted) {
      setState(() {
        _virtualDevices = list;
        _activeVirtualDevice =
            list.where((a) => a.uuid == activeUuid).firstOrNull ??
            list.firstOrNull;
      });
    }
  }

  /// Reloads all settings UI state from [SettingsService] (e.g. after
  /// switching to a different VirtualDevice in the VirtualDevicesScreen).
  void _reloadFromSettings() {
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
    _timelineHistoryDays = s.timelineHistoryDays;
    _searchCountry = s.searchCountry;
    _searchCountryCtrl.text = _searchCountry;
    _addressOnAutoCreate = s.addressOnAutoCreate;
    _addressOnManualCreate = s.addressOnManualCreate;
    _addressOnInterval = s.addressOnInterval;
    _schedulerColorRange = s.schedulerColorRange;
    setState(() {});
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
    s.photoMaxWidth = _photoMaxWidth;
    s.photoMaxHeight = _photoMaxHeight;
    s.photoImageQuality = _photoImageQuality;
    s.placeDetailPhotoCount = _placeDetailPhotoCount;
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
    // Persist settings back into the active VirtualDevice.
    final a = _activeVirtualDevice;
    if (a != null) {
      await DatabaseService.instance.updateVirtualDevice(
        s.snapshotAsVirtualDevice(uuid: a.uuid, name: a.name),
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
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: UnifiedWidget(context).saveButton(
              onPressed: () async {
                await _saveAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: [
            // ── Aktivität ─────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: Text(_activeVirtualDevice?.name ?? l10n.noVirtualDevices),
              subtitle: Text(l10n.virtualDevicesCount(_virtualDevices.length)),
              onTap: () async {
                await _saveAll();
                if (!context.mounted) return;
                await Navigator.pushNamed(context, '/virtual-devices');
                await _loadVirtualDevices();
                if (context.mounted) _reloadFromSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: Text(l10n.trustedSourcesTitle),
              subtitle: Text(l10n.trustedSourcesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/trusted-sources'),
            ),
            // ── Verwaltung ───────────────────────────────────────────────
            UnifiedWidget(context).namedDivider(l10n.sectionManagement),
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
              leading: const MatrixIcon(size: 32.0),
              title: Text(l10n.matrixConnections),
              subtitle: Text(l10n.matrixConnectionsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/matrix-connections'),
            ),

            ListTile(
              leading: telegramIcon(),
              title: Text(l10n.telegramConnections),
              subtitle: Text(l10n.telegramConnectionsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  Navigator.pushNamed(context, '/telegram-connections'),
            ),
            if (!(Platform.isLinux ||
                Platform.isWindows ||
                Platform.isMacOS)) ...[
              SwitchListTile(
                secondary: const Icon(Icons.calendar_month),
                title: Text(l10n.calendarSync),
                subtitle: Text(l10n.calendarSyncSubtitle),
                value: SettingsService.instance.calendarEnabled,
                onChanged: (v) => setState(
                  () => SettingsService.instance.calendarEnabled = v,
                ),
              ),

              if (SettingsService.instance.calendarEnabled)
                Padding(
                  padding: const EdgeInsets.only(left: 32.0),
                  child: ListTile(
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
                              granted
                                  ? l10n.calendarGranted
                                  : l10n.calendarDenied,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
            ],
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(l10n.syncSources),
              subtitle: Text(l10n.syncSourcesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/sync-sources'),
            ),

            // ── Fotos ────────────────────────────────────────────────────
            UnifiedWidget(context).namedDivider(l10n.sectionPhotos),
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
            ListTile(
              title: Text(l10n.placeDetailPhotoCount(_placeDetailPhotoCount)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Slider(
                    value: _placeDetailPhotoCount.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$_placeDetailPhotoCount',
                    onChanged: (v) =>
                        setState(() => _placeDetailPhotoCount = v.round()),
                  ),
                  Text(
                    l10n.placeDetailPhotoCountSubtitle,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            // ── Kartendarstellung ─────────────────────────────────────────
            UnifiedWidget(context).namedDivider(l10n.sectionMapDisplay),
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
            // ── Planer ──────────────────────────────────────────────────
            UnifiedWidget(context).namedDivider(l10n.sectionPlanner),
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
            // ── Adresssuche ───────────────────────────────────────────────
            UnifiedWidget(context).namedDivider(l10n.sectionAddressSearch),
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
            // ── Tracking Settings ─────────────────────────────────────────
            UnifiedWidget(context).namedDivider(l10n.sectionTracking),
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
            // ───── Database ──────────────────────────────────────────────────
            UnifiedWidget(context).namedDivider(l10n.sectionDatabase),

            ListTile(
              leading: const Icon(Icons.storage),
              title: Text(l10n.databaseDump),
              subtitle: Text(l10n.databaseDumpSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/database-dump'),
            ),
            ListTile(
              leading: const Icon(Icons.no_accounts),
              title: Text(l10n.dbPurgeForeignDevicesTitle),
              subtitle: Text(l10n.dbPurgeForeignDevicesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.dbPurgeForeignDevicesConfirmTitle),
                    content: Text(l10n.dbPurgeForeignDevicesConfirmContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.ok),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                if (!context.mounted) return;
                final deleted = await DatabaseService.instance
                    .deleteUntrustedDeviceEntries();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.dbPurgeForeignDevicesSuccess(deleted)),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: Text(l10n.dbPurgeDeletedTitle),
              subtitle: Text(l10n.dbPurgeDeletedSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.dbPurgeDeletedConfirmTitle),
                    content: Text(l10n.dbPurgeDeletedConfirmContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.ok),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                if (!context.mounted) return;
                final deleted = await DatabaseService.instance
                    .purgeDeletedRecords();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.dbPurgeDeletedSuccess(deleted)),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore_from_trash),
              title: Text(l10n.dbRestoreDeletedTitle),
              subtitle: Text(l10n.dbRestoreDeletedSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.dbRestoreDeletedConfirmTitle),
                    content: Text(l10n.dbRestoreDeletedConfirmContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.ok),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                if (!context.mounted) return;
                final count = await DatabaseService.instance
                    .restoreDeletedRecords();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.dbRestoreDeletedSuccess(count)),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.update_disabled),
              title: Text(l10n.dbResetUpdatedAtTitle),
              subtitle: Text(l10n.dbResetUpdatedAtSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.dbResetUpdatedAtConfirmTitle),
                    content: Text(l10n.dbResetUpdatedAtConfirmContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.ok),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                if (!context.mounted) return;
                final count = await DatabaseService.instance.resetUpdatedAt();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.dbResetUpdatedAtSuccess(count)),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(l10n.dbSetUpdatedAtTitle),
              subtitle: Text(l10n.dbSetUpdatedAtSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final now = DateTime.now();
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate == null) return;
                if (!context.mounted) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(now),
                );
                if (pickedTime == null) return;
                if (!context.mounted) return;
                final chosen = DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.dbSetUpdatedAtConfirmTitle),
                    content: Text(l10n.dbSetUpdatedAtConfirmContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.ok),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                if (!context.mounted) return;
                final count = await DatabaseService.instance.setUpdatedAt(
                  chosen.millisecondsSinceEpoch,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.dbSetUpdatedAtSuccess(count))),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: Text(l10n.dbCleanupTitle),
              subtitle: Text(l10n.dbCleanupSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.dbCleanupConfirmTitle),
                    content: Text(l10n.dbCleanupConfirmContent),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.ok),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                if (!context.mounted) return;
                final result = await DatabaseService.instance
                    .cleanupOrphanedRecords();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.dbCleanupSuccess(result))),
                  );
                }
              },
            ),
            // ── Berechtigungen ───────────────────────────────────────────
            UnifiedWidget(context).namedDivider(l10n.sectionPermissions),
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
            const Divider(),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: UnifiedWidget(context).saveAndCancelButtonsRow(
                onSavePressed: () async {
                  await _saveAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.settingsSaved)));
                  }
                },
                onCancelPressed: () => Navigator.pop(context),
              ),
            ),

            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Chaos Tours'),
              subtitle: Text('Version 2.0.0'),
            ),
            ..._buildDevToolsSection(l10n),
          ],
        ),
      ),
    );
  }

  // ── VirtualDevice helpers ────────────────────────────────────────────────────

  /// Builds the potentially destructive developer tools, always rendered at the
  /// very bottom of the settings list. The tools are only visible while unlocked
  /// (for one hour after solving the type-in challenge).
  List<Widget> _buildDevToolsSection(AppLocalizations l10n) {
    final unlocked = SettingsService.instance.devToolsUnlocked;

    if (!unlocked) {
      return [
        UnifiedWidget(context).namedDivider(l10n.devToolsSectionTitle),
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

    final success = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => _DevToolsChallengeDialog(code: code),
    );

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
}

// ---------------------------------------------------------------------------
// Extracted dialog widget so the TextEditingController is owned by State and
// properly disposed, avoiding the _dependents / GlobalKey crash on close.
// ---------------------------------------------------------------------------
class _DevToolsChallengeDialog extends StatefulWidget {
  final String code;
  const _DevToolsChallengeDialog({required this.code});

  @override
  State<_DevToolsChallengeDialog> createState() =>
      _DevToolsChallengeDialogState();
}

class _DevToolsChallengeDialogState extends State<_DevToolsChallengeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final input = _controller.text.trim().toUpperCase();
    final matches = input == widget.code;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.devToolsSectionTitle)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  widget.code,
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
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: l10n.devToolsChallengeHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
