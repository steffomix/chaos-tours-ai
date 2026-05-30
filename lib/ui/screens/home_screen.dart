import 'package:flutter/material.dart';

import '../../models/tour.dart';
import '../../services/calendar_service.dart';
import '../../services/database_service.dart';
import '../../services/foreground_service_handler.dart';
import '../../utils/permission_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Tour> _tours = [];
  Tour? _activeTour;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTours();
    // Listen for position updates from foreground service
    ForegroundServiceManager.addPositionListener(_onPosition);
  }

  @override
  void dispose() {
    ForegroundServiceManager.removePositionListener(_onPosition);
    super.dispose();
  }

  void _onPosition(Map data) {
    // Could display live position; for now just keep UI in sync.
    if (mounted) setState(() {});
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
      await ForegroundServiceManager.startService(tour);
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
