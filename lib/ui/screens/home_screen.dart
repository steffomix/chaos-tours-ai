import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../models/saved_place.dart';
import '../../models/stay.dart';
import '../../models/tour.dart';
import '../../services/calendar_service.dart';
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
  List<Tour> _tours = [];
  Tour? _activeTour;
  bool _isLoading = false;

  // Tracking state
  bool _trackingEnabled = false;
  Stay? _activeStay;
  SavedPlace? _activeStayPlace;
  String _trackingStatusText = 'Inaktiv';

  @override
  void initState() {
    super.initState();
    _trackingEnabled = SettingsService.instance.trackingEnabled;
    _loadTours();
    _loadActiveStay();
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

  Future<void> _loadTours() async {
    final tours = await DatabaseService.instance.loadAllTours();
    final active = await DatabaseService.instance.loadActiveTour();
    if (mounted) {
      setState(() {
        _tours = tours;
        _activeTour = active;
      });
    }
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

  Future<void> _startTour() async {
    final nameController = TextEditingController(
      text: 'Tour ${DateTime.now().toLocal().toString().substring(0, 16)}',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tour starten'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Tour-Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Starten'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Check permissions first
    final hasPerms = await PermissionHelper.instance.hasAllPermissions();
    if (!hasPerms) {
      await PermissionHelper.instance.requestLocationPermission();
      await PermissionHelper.instance.requestBackgroundLocationPermission();
      await PermissionHelper.instance.requestNotificationPermission();
    }
    await _ensureBatteryOptimizationExempt();

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      var tour = Tour(name: nameController.text.trim(), startTime: now);
      final id = await DatabaseService.instance.insertTour(tour);
      tour = tour.copyWith(id: id);

      // Calendar event
      final calPerms = await PermissionHelper.instance
          .requestCalendarPermission();
      if (calPerms) {
        final eventId = await CalendarService.instance.createTourEvent(tour);
        if (eventId != null) {
          tour = tour.copyWith(calendarEventId: eventId);
          await DatabaseService.instance.updateTour(tour);
        }
      }

      // Start foreground service
      await ForegroundServiceManager.startService(
        notificationText: 'Tour "${tour.name}" wird aufgezeichnet…',
      );
      ForegroundServiceManager.sendStartTour(id);

      await _loadTours();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stopTour() async {
    final active = _activeTour;
    if (active == null) return;

    setState(() => _isLoading = true);
    try {
      ForegroundServiceManager.sendStopTour();
      await ForegroundServiceManager.stopService();

      final ended = active.copyWith(
        endTime: DateTime.now().millisecondsSinceEpoch,
      );
      await DatabaseService.instance.updateTour(ended);

      // Update calendar event with actual end time
      await CalendarService.instance.updateTourEvent(ended);

      await _loadTours();
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      // Only stop service if no manual tour is running
      if (_activeTour == null) {
        await ForegroundServiceManager.stopService();
      }
    }
  }

  Future<void> _deleteTour(Tour tour) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tour löschen?'),
        content: Text('„${tour.name}" wirklich löschen?'),
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
    await CalendarService.instance.deleteTourEvent(tour);
    await DatabaseService.instance.deleteTour(tour.id!);
    await _loadTours();
  }

  String _formatDuration(Tour tour) {
    final start = tour.startDateTime;
    final end = tour.endDateTime ?? DateTime.now();
    final diff = end.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '${h}h ${m}min';
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tracking switch
                SwitchListTile(
                  secondary: Icon(
                    _trackingEnabled
                        ? Icons.my_location
                        : Icons.location_disabled,
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
                          return Text(
                            h > 0 ? 'Seit ${h}h ${m}min' : 'Seit ${m}min',
                          );
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
                // Active tour card
                if (_activeTour != null)
                  Card(
                    margin: const EdgeInsets.all(12),
                    color: Colors.green.shade50,
                    child: ListTile(
                      leading: const Icon(
                        Icons.play_circle,
                        color: Colors.green,
                        size: 32,
                      ),
                      title: Text(
                        _activeTour!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Läuft seit ${_formatDuration(_activeTour!)}',
                      ),
                      trailing: FilledButton.icon(
                        onPressed: _stopTour,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stopp'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ),
                // Tour list
                Expanded(
                  child: _tours.isEmpty
                      ? const Center(
                          child: Text(
                            'Noch keine Touren vorhanden.\nDrücke + um eine Tour zu starten.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _tours.length,
                          itemBuilder: (ctx, i) {
                            final tour = _tours[i];
                            final running = tour.isRunning;
                            return ListTile(
                              leading: Icon(
                                running
                                    ? Icons.play_circle
                                    : Icons.check_circle,
                                color: running ? Colors.green : Colors.grey,
                              ),
                              title: Text(tour.name),
                              subtitle: Text(
                                running
                                    ? 'Läuft – ${_formatDuration(tour)}'
                                    : _formatDuration(tour),
                              ),
                              trailing: running
                                  ? null
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _deleteTour(tour),
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: _activeTour == null
          ? FloatingActionButton(
              onPressed: _startTour,
              tooltip: 'Tour starten',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
