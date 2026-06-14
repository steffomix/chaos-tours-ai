import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:focus_detector/focus_detector.dart';

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
  String _trackingStatusText = 'Tracking deaktiviert';

  // Recent visits
  List<Stay> _recentStays = [];
  Map<String, SavedPlace> _placesByUuid = {};

  @override
  void initState() {
    super.initState();
    // Do NOT trust the persisted flag alone — the service may have been killed.
    // Resolve the actual service state asynchronously and correct if needed.
    _checkActualTrackingState();
    _loadActiveStay();
    _loadCurrentAktivitaet();
    _loadRecentStays();
  }

  Future<void> _checkActualTrackingState() async {
    final serviceRunning = await FlutterForegroundTask.isRunningService;
    final storedEnabled = SettingsService.instance.trackingEnabled;

    // If the stored flag claims tracking is on but the service isn't running,
    // reset the flag so the UI reflects reality.
    if (storedEnabled && !serviceRunning) {
      SettingsService.instance.trackingEnabled = false;
    }

    if (mounted) {
      setState(() {
        _trackingEnabled = serviceRunning;
        _trackingStatusText = serviceRunning
            ? 'Tracking läuft…'
            : 'Tracking deaktiviert';
      });
    }
  }

  @override
  void dispose() {
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
          text = 'Halten bei ${_cutText(placeName) ?? 'bekanntem Ort'}';
        case 'haltAtUnknown':
          text = address != null ? 'Halten: ${_cutText(address)}' : 'Halten';
        case 'detectingHalt':
          text = 'Aufenthalt wird erkannt…';
        case 'moving':
          text = 'Unterwegs';
        default:
          text = 'Tracking aktiv';
      }
      _loadActiveStay(build: false);
      _loadRecentStays(build: false);
      if (mounted) setState(() => _trackingStatusText = text);
    }
  }

  String? _cutText(String? text, {int maxLength = 20}) {
    if (text == null) return null;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}…';
  }

  Future<void> _loadRecentStays({bool build = true}) async {
    final stays = await DatabaseService.instance.loadRecentCompletedStays();
    final allPlaces = await DatabaseService.instance.loadAllPlaces();
    final byUuid = {for (final p in allPlaces) p.uuid: p};
    if (mounted && build) {
      setState(() {
        _recentStays = stays;
        _placesByUuid = byUuid;
      });
    }
  }

  Future<void> _loadCurrentAktivitaet() async {
    final uuid = SettingsService.instance.activeAktivitaetUuid;
    if (uuid == null) return;
    final a = await DatabaseService.instance.loadAktivitaet(uuid);
    if (mounted) setState(() => _currentAktivitaet = a);
  }

  Future<void> _loadActiveStay({bool build = true}) async {
    final stay = await DatabaseService.instance.loadActiveStay();
    SavedPlace? place;
    if (stay?.placeUuid != null) {
      final places = await DatabaseService.instance.loadAllPlaces();
      place = places.where((p) => p.uuid == stay!.placeUuid).firstOrNull;
    }
    if (mounted && build) {
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
          .hasLocationPermission();
      if (!locationGranted) return;

      final batteryOk = await _ensureBatteryOptimizationExempt();
      if (!batteryOk) return;
    }

    setState(() {
      _trackingEnabled = value;
      _trackingStatusText = value
          ? 'Tracking sammelt GPS Daten…'
          : 'Tracking deaktiviert';
    });
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
      try {
        await ForegroundServiceManager.stopService();
      } catch (_) {
        // Ignore errors when stopping the service
      }
    }
  }

  Future<void> _confirmToggleTracking() async {
    final newValue = !_trackingEnabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          newValue ? 'Tracking aktivieren?' : 'Tracking deaktivieren?',
        ),
        content: Text(
          newValue
              ? 'Soll das automatische Hintergrund-Tracking gestartet werden?'
              : 'Soll das automatische Hintergrund-Tracking gestoppt werden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newValue ? 'Aktivieren' : 'Deaktivieren'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _toggleTracking(newValue);
  }

  @override
  Widget build(BuildContext context) {
    return FocusDetector(
      onFocusGained: () {
        ForegroundServiceManager.addDataListener(_onServiceData);
        _loadActiveStay().then((_) {
          if (mounted) {
            _loadRecentStays().then((_) {
              if (mounted) {
                setState(() {}); // Refresh to show tracking points if enabled.
              }
            });
          }
        });
      },
      onFocusLost: () =>
          ForegroundServiceManager.removeDataListener(_onServiceData),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chaos Tours'),
          actions: [
            IconButton(
              icon: Icon(
                _trackingEnabled ? Icons.my_location : Icons.location_disabled,
                color: _trackingEnabled
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              tooltip: _trackingEnabled ? 'Tracking aktiv' : 'Tracking inaktiv',
              onPressed: _confirmToggleTracking,
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
                        Icons.settings,
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

            const SizedBox(height: 7, width: 6),
            // Tracking status row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.sensors,
                    size: 16,
                    color: _trackingEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _trackingStatusText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _trackingEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            // ── Aktueller Aufenthalt ───────────────────────────────
            if (_activeStay != null) ...[
              Card(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                elevation: 3,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => StayDetailSheet(
                        stay: _activeStay!,
                        onUpdated: _loadActiveStay,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _activeStayPlace != null
                            ? CircleAvatar(
                                backgroundColor: _activeStayPlace!
                                    .placeType
                                    .dotColor
                                    .withValues(alpha: 0.2),
                                child: Icon(
                                  _activeStayPlace!.placeType.icon,
                                  color: _activeStayPlace!.placeType.dotColor,
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.15),
                                child: Icon(
                                  Icons.location_on,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _activeStayPlace?.name ??
                                    _activeStay!.address ??
                                    'Unbekannter Ort',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Builder(
                                builder: (ctx) {
                                  final dur = _activeStay!.duration;
                                  final h = dur.inHours;
                                  final m = dur.inMinutes % 60;
                                  return Text(
                                    h > 0
                                        ? 'Seit ${h}h ${m}min'
                                        : 'Seit ${m}min',
                                    style: Theme.of(ctx).textTheme.bodySmall,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                  ),
                  icon: const Icon(Icons.call_split, size: 18),
                  label: const Text('Aufenthalt jetzt beenden & teilen'),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Aufenthalt beenden?'),
                        content: const Text(
                          'Der aktuelle Aufenthalt wird jetzt abgeschlossen. '
                          'Das Tracking läuft weiter und startet bei gleichem Ort '
                          'sofort einen neuen Aufenthalt.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Abbrechen'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Beenden'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    ForegroundServiceManager.sendForceEndStay();
                    await Future<void>.delayed(
                      const Duration(milliseconds: 300),
                    );
                    _loadActiveStay();
                    _loadRecentStays();
                  },
                ),
              ),
            ],
            const Divider(height: 1),
            // ── Letzte Besuche ─────────────────────────────────────
            Expanded(
              child: _recentStays.isEmpty
                  ? const Center(
                      child: Text(
                        'Noch keine Besuche aufgezeichnet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRecentStays,
                      child: ListView.builder(
                        itemCount: _recentStays.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                'Letzte Besuche',
                                style: Theme.of(ctx).textTheme.titleSmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                            );
                          }
                          final stay = _recentStays[i - 1];
                          final place = stay.placeUuid != null
                              ? _placesByUuid[stay.placeUuid]
                              : null;
                          final name =
                              place?.name ?? stay.address ?? 'Unbekannter Ort';
                          final dur = stay.duration;
                          final h = dur.inHours;
                          final m = dur.inMinutes % 60;
                          final durText = h > 0 ? '${h}h ${m}min' : '${m}min';
                          final start = DateTime.fromMillisecondsSinceEpoch(
                            stay.startTime,
                          );
                          final dateText =
                              '${start.day.toString().padLeft(2, '0')}.${start.month.toString().padLeft(2, '0')}.${start.year}  '
                              '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
                          return ListTile(
                            dense: true,
                            leading: place != null
                                ? Icon(
                                    place.placeType.icon,
                                    color: place.placeType.dotColor,
                                    size: 22,
                                  )
                                : const Icon(
                                    Icons.location_on,
                                    size: 22,
                                    color: Colors.grey,
                                  ),
                            title: Text(name),
                            subtitle: Text('$dateText · $durText'),
                            onTap: () {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                builder: (_) => StayDetailSheet(
                                  stay: stay,
                                  onUpdated: _loadRecentStays,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
