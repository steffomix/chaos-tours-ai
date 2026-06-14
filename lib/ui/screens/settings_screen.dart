import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Einstellungen gespeichert')),
                );
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Aktivität ─────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Aktivität',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bolt),
            title: Text(_activeAktivitaet?.name ?? 'Keine Aktivität'),
            subtitle: Text(
              '${_aktivitaeten.length} '
              '${_aktivitaeten.length == 1 ? 'Aktivität' : 'Aktivitäten'} vorhanden',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Umbenennen',
                  onPressed: _activeAktivitaet == null
                      ? null
                      : () => _renameAktivitaet(_activeAktivitaet!),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: 'Wechseln / Neu erstellen',
                  onPressed: _showAktivitaetenPicker,
                ),
              ],
            ),
          ),
          const Divider(),
          // ── Tracking Settings ─────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Tracking',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: Text('GPS-Intervall: ${_gpsInterval}s'),
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
                const Text(
                  'Hinweis: Änderungen werden erst nach Neustart des Trackings wirksam.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(
              'GPS-Glättung: '
              '${_gpsSmoothingPoints == 1 ? 'deaktiviert' : '$_gpsSmoothingPoints Punkte'}',
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
                const Text(
                  'Mittelt die letzten N GPS-Punkte.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text(
              'Aufenthalt erkennen nach: ${(_stayDetection / 60).toStringAsFixed(0)} min',
            ),
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
            title: Text(
              'Auto-Ort erstellen nach: ${(_autoPlaceTime / 60).toStringAsFixed(0)} min',
            ),
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
              'Standard-Radius: ${_defaultRadius.toStringAsFixed(0)} m',
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
          SwitchListTile(
            title: const Text('Orte automatisch erstellen'),
            subtitle: const Text(
              'Neue Orte bei langen Aufenthalten an unbekannten Orten anlegen',
            ),
            value: _autoCreatePlaces,
            onChanged: (v) => setState(() => _autoCreatePlaces = v),
          ),
          if (_autoCreatePlaces)
            ListTile(
              title: const Text('Gruppe für Auto-Orte'),
              trailing: DropdownButton<String?>(
                value: _autoPlaceGroupUuid == null
                    ? null
                    : (_groups.any((g) => g.uuid == _autoPlaceGroupUuid)
                          ? _autoPlaceGroupUuid
                          : null),
                hint: const Text('Keine'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Keine')),
                  ..._groups.map(
                    (g) => DropdownMenuItem(value: g.uuid, child: Text(g.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _autoPlaceGroupUuid = v),
              ),
            ),
          ListTile(
            title: const Text('Standard-Gruppe für neue Orte'),
            subtitle: const Text(
              'Voreingestellte Gruppe beim manuellen Erstellen von Orten',
            ),
            trailing: DropdownButton<String?>(
              value: _defaultPlaceGroupUuid == null
                  ? null
                  : (_groups.any((g) => g.uuid == _defaultPlaceGroupUuid)
                        ? _defaultPlaceGroupUuid
                        : null),
              hint: const Text('Keine'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Keine')),
                ..._groups.map(
                  (g) => DropdownMenuItem(value: g.uuid, child: Text(g.name)),
                ),
              ],
              onChanged: (v) => setState(() => _defaultPlaceGroupUuid = v),
            ),
          ),
          const Divider(),
          // ── Kartendarstellung ─────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Kartendarstellung',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: const Text('GPS-Punkte anzeigen'),
            subtitle: const Text(
              'Tracking-Punkte farbig auf der Karte einblenden',
            ),
            value: _showTrackingPoints,
            onChanged: (v) => setState(() => _showTrackingPoints = v),
          ),
          if (_showTrackingPoints)
            ListTile(
              title: Text(
                'Punktgröße: ${_trackingPointRadius.toStringAsFixed(1)} m',
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
              'Zeitachsen-Verlauf: $_timelineHistoryDays '
              '${_timelineHistoryDays == 1 ? 'Tag' : 'Tage'}',
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
                const Text(
                  'Wie viele Tage der Reiseverlauf auf der Zeitachsen-Karte angezeigt wird.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(),
          // ── Planer ──────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Planer',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: Text(
              'Farbskala-Bereich: $_schedulerColorRange '
              '${_schedulerColorRange == 1 ? 'Tag' : 'Tage'}',
            ),
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
                  '$_schedulerColorRange Tage = grün  •  0 = gelb  •  -$_schedulerColorRange = rot',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Angezeigte Gruppen (Karte & Planer)'),
            subtitle: _groups.isEmpty
                ? const Text('Keine Gruppen vorhanden')
                : Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('Alle'),
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
          const Divider(),
          // ── Adresssuche ───────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Adresssuche',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Standard-Land für Adresssuche'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCountryCtrl,
                  decoration: const InputDecoration(
                    hintText: 'z. B. Deutschland',
                    isDense: true,
                  ),
                  onChanged: (v) => _searchCountry = v,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Wird in der Karten-Adresssuche als Standardland vorausgefüllt.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(),
          // ── Verwaltung ───────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Verwaltung',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Ortsgruppen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/place-groups'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Personen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/persons'),
          ),
          ListTile(
            leading: const Icon(Icons.work_outline),
            title: const Text('Tätigkeiten'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/activities'),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Datenbank-Dump'),
            subtitle: const Text('Dump erstellen, laden & teilen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/database-dump'),
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Sync-Quellen'),
            subtitle: const Text('Sync-Server verwalten und synchronisieren'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/sync-sources'),
          ),
          const Divider(),
          // ── Berechtigungen ───────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Berechtigungen',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Standortberechtigung'),
            subtitle: const Text('Standort im Vordergrund anfordern'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await PermissionHelper.instance
                  .requestLocationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted ? 'Standort gewährt' : 'Standort verweigert',
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_searching),
            title: const Text('Hintergrund-Standort'),
            subtitle: const Text('Standort im Hintergrund anfordern'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await PermissionHelper.instance
                  .requestBackgroundLocationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted
                          ? 'Hintergrund-Standort gewährt'
                          : 'Hintergrund-Standort verweigert',
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Benachrichtigungen'),
            subtitle: const Text('Benachrichtigungsberechtigung anfordern'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final granted = await PermissionHelper.instance
                  .requestNotificationPermission();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted
                          ? 'Benachrichtigungen gewährt'
                          : 'Benachrichtigungen verweigert',
                    ),
                  ),
                );
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.calendar_today),
            title: const Text('Kalender-Sync'),
            subtitle: const Text(
              'Aufenthalte automatisch im Gerätekalender eintragen',
            ),
            value: SettingsService.instance.calendarEnabled,
            onChanged: (v) =>
                setState(() => SettingsService.instance.calendarEnabled = v),
          ),
          if (SettingsService.instance.calendarEnabled)
            ListTile(
              leading: const Icon(Icons.lock_open_outlined),
              title: const Text('Kalenderberechtigung anfordern'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final granted = await PermissionHelper.instance
                    .requestCalendarPermission();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        granted ? 'Kalender gewährt' : 'Kalender verweigert',
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
                '„${_activeAktivitaet!.name}" löschen',
                style: const TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Aktuelle Aktivität dauerhaft entfernen'),
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
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.bolt),
                        SizedBox(width: 8),
                        Text(
                          'Aktivität wählen',
                          style: TextStyle(
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
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        a.name,
                        style: isActive
                            ? TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
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
                    title: const Text('Neue Aktivität erstellen'),
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
    final nameCtrl = TextEditingController(
      text: 'Aktivität ${_aktivitaeten.length + 1}',
    );
    // Offer to copy from an existing one as template.
    Aktivitaet template = _activeAktivitaet ?? Aktivitaet(name: '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neue Aktivität'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            if (_aktivitaeten.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Einstellungen kopieren von:',
                style: TextStyle(fontSize: 13),
              ),
              StatefulBuilder(
                builder: (ctx2, setInner) => DropdownButton<Aktivitaet>(
                  isExpanded: true,
                  value: template,
                  items: _aktivitaeten
                      .map(
                        (a) => DropdownMenuItem(value: a, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setInner(() => template = v);
                  },
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final newA = template.copyWith(name: name);
    final id = await DatabaseService.instance.insertAktivitaet(newA);
    final created = await DatabaseService.instance.loadAktivitaet(id);
    if (created != null) await _switchAktivitaet(created);
    await _loadAktivitaeten();
  }

  Future<void> _renameAktivitaet(Aktivitaet a) async {
    final ctrl = TextEditingController(text: a.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aktivität umbenennen'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
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
      builder: (ctx) => AlertDialog(
        title: const Text('Aktivität löschen?'),
        content: Text(
          '„${a.name}" wirklich löschen?\n\n'
          'Die Einstellungen dieser Aktivität werden unwiderruflich entfernt.',
        ),
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

    // Switch to another Aktivitaet before deleting.
    final next = _aktivitaeten.firstWhere((x) => x.uuid != a.uuid);
    await _switchAktivitaet(next);
    await DatabaseService.instance.deleteAktivitaet(a.uuid);
    await _loadAktivitaeten();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('„${a.name}" gelöscht')));
    }
  }
}
