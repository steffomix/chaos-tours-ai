import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../models/aktivitaet.dart';
import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../services/database_service.dart';
import '../../services/foreground_service_handler.dart';
import '../../services/settings_service.dart';
import '../../utils/permission_helper.dart';
import '../widgets/stay_detail_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Active Aktivitaet
  Aktivitaet? _currentAktivitaet;

  // Tracking state
  bool _trackingEnabled = false;
  Stay? _activeStay;
  SavedPlace? _activeStayPlace;
  String _trackingStatusText = 'Inaktiv';

  @override
  void initState() {
    super.initState();
    _trackingEnabled = SettingsService.instance.trackingEnabled;
    _loadActiveStay();
    _loadCurrentAktivitaet();
    ForegroundServiceManager.addDataListener(_onServiceData);
  }

  @override
  void dispose() {
    ForegroundServiceManager.removeDataListener();
    super.dispose();
  }

  void _onServiceData(Map data) {
    final cmd = data['cmd'] as String?;
    if (cmd == FgTaskKeys.position) {
      if (mounted) setState(() {});
    } else if (cmd == FgTaskKeys.trackingStatus) {
      final statusName = data['status'] as String? ?? 'idle';
      final placeName = data['place_name'] as String?;
      final address = data['address'] as String?;
      String text;
      switch (statusName) {
        case 'haltAtKnown':
          text = 'Halten bei ${placeName ?? 'bekanntem Ort'}';
        case 'haltAtUnknown':
          text = address != null ? 'Halten: $address' : 'Halten';
        case 'detectingHalt':
          text = 'Aufenthalt wird erkannt…';
        case 'moving':
          text = 'Unterwegs';
        default:
          text = 'Tracking aktiv';
      }
      _loadActiveStay();
      if (mounted) setState(() => _trackingStatusText = text);
    }
  }

  Future<void> _loadCurrentAktivitaet() async {
    final id = SettingsService.instance.activeAktivitaetId;
    if (id == null) return;
    final a = await DatabaseService.instance.loadAktivitaet(id);
    if (mounted) setState(() => _currentAktivitaet = a);
  }

  Future<void> _loadActiveStay() async {
    final stay = await DatabaseService.instance.loadActiveStay();
    SavedPlace? place;
    if (stay?.placeId != null) {
      final places = await DatabaseService.instance.loadAllPlaces();
      place = places.where((p) => p.id == stay!.placeId).firstOrNull;
    }
    if (mounted) {
      setState(() {
        _activeStay = stay;
        _activeStayPlace = place;
      });
    }
  }

  /// Checks battery-optimization status and requests exemption if needed.
  /// Returns false when the user must first grant the exemption manually and
  /// the service start should be aborted.
  Future<bool> _ensureBatteryOptimizationExempt() async {
    final ignoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (ignoring) return true;

    // Ask Android to whitelist this app via the standard system dialog.
    // Requires REQUEST_IGNORE_BATTERY_OPTIMIZATIONS in the manifest.
    final result =
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    if (result is ServiceRequestSuccess) return true;

    // If the direct request failed (e.g. Samsung blocks it), open the
    // battery settings page and tell the user what to do.
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Akkuoptimierung deaktivieren'),
        content: const Text(
          'Der Hintergrund-Dienst konnte nicht gestartet werden.\n\n'
          'Bitte deaktiviere die Akkuoptimierung für Chaos Tours:\n'
          'Einstellungen → Apps → Chaos Tours → Akku → Nicht eingeschränkt',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
            },
            child: const Text('Einstellungen öffnen'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _toggleTracking(bool value) async {
    if (value) {
      // All three permissions are required for the foreground service:
      // location (fine), background location, and POST_NOTIFICATIONS (Android 13+).
      final hasPerms = await PermissionHelper.instance.hasAllPermissions();
      if (!hasPerms) {
        await PermissionHelper.instance.requestLocationPermission();
        await PermissionHelper.instance.requestBackgroundLocationPermission();
        await PermissionHelper.instance.requestNotificationPermission();
      }
      final locationGranted = await PermissionHelper.instance
          .requestLocationPermission();
      if (!locationGranted) return;

      final batteryOk = await _ensureBatteryOptimizationExempt();
      if (!batteryOk) return;
    }

    setState(() => _trackingEnabled = value);
    SettingsService.instance.trackingEnabled = value;

    if (value) {
      final result = await ForegroundServiceManager.startService(
        notificationText: 'Automatisches Tracking aktiv',
      );
      if (result is ServiceRequestFailure) {
        debugPrint('[Tracking] startService FAILED: ${result.error}');
        // Revert optimistic UI state on failure.
        if (mounted) {
          setState(() => _trackingEnabled = false);
          SettingsService.instance.trackingEnabled = false;
        }
        return;
      }
      debugPrint('[Tracking] startService OK');
    }
    ForegroundServiceManager.sendSetTracking(value);

    if (!value) {
      await ForegroundServiceManager.stopService();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chaos Tours'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Active Aktivitaet banner ───────────────────────────
          Material(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: InkWell(
              onTap: () async {
                await Navigator.pushNamed(context, '/settings');
                _loadCurrentAktivitaet();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 18,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentAktivitaet?.name ?? 'Aktivität laden…',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tracking switch
          SwitchListTile(
            secondary: Icon(
              _trackingEnabled ? Icons.my_location : Icons.location_disabled,
              color: _trackingEnabled
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: const Text('Automatisches Tracking'),
            subtitle: _trackingEnabled
                ? Text(_trackingStatusText)
                : const Text('Aufenthalte automatisch erkennen'),
            value: _trackingEnabled,
            onChanged: _toggleTracking,
          ),
          // Active auto-stay card
          if (_activeStay != null && _trackingEnabled)
            Card(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.5),
              child: ListTile(
                leading: Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  _activeStayPlace?.name ??
                      _activeStay!.address ??
                      'Unbekannter Ort',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Builder(
                  builder: (ctx) {
                    final dur = _activeStay!.duration;
                    final h = dur.inHours;
                    final m = dur.inMinutes % 60;
                    return Text(h > 0 ? 'Seit ${h}h ${m}min' : 'Seit ${m}min');
                  },
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_note),
                  tooltip: 'Aufenthalt bearbeiten',
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => StayDetailSheet(
                        stay: _activeStay!,
                        onUpdated: _loadActiveStay,
                      ),
                    );
                  },
                ),
              ),
            ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
