import 'package:flutter/material.dart';

import '../../models/place_group.dart';
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
  int? _autoPlaceGroupId;
  List<PlaceGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    final s = SettingsService.instance;
    _gpsInterval = s.gpsIntervalSeconds;
    _stayDetection = s.stayDetectionSeconds;
    _autoPlaceTime = s.autoPlaceSeconds;
    _defaultRadius = s.defaultRadiusMeters;
    _autoCreatePlaces = s.autoCreatePlaces;
    _autoPlaceGroupId = s.autoPlaceGroupId;
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseService.instance.loadAllPlaceGroups();
    if (mounted) setState(() => _groups = groups);
  }

  Future<void> _saveAll() async {
    final s = SettingsService.instance;
    s.gpsIntervalSeconds = _gpsInterval;
    s.stayDetectionSeconds = _stayDetection;
    s.autoPlaceSeconds = _autoPlaceTime;
    s.defaultRadiusMeters = _defaultRadius;
    s.autoCreatePlaces = _autoCreatePlaces;
    s.autoPlaceGroupId = _autoPlaceGroupId;
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
          // ── Tracking Settings ─────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
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
              trailing: DropdownButton<int?>(
                value: _autoPlaceGroupId,
                hint: const Text('Keine'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Keine')),
                  ..._groups.map(
                    (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _autoPlaceGroupId = v),
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
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Kalender'),
            subtitle: const Text('Kalenderberechtigung anfordern'),
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
        ],
      ),
    );
  }
}
