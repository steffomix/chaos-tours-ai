import 'package:flutter/material.dart';

import '../../models/tracking_log_entry.dart';
import '../../services/database_service.dart';

class TrackingLogScreen extends StatefulWidget {
  const TrackingLogScreen({super.key});

  @override
  State<TrackingLogScreen> createState() => _TrackingLogScreenState();
}

class _TrackingLogScreenState extends State<TrackingLogScreen> {
  List<TrackingLogEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await DatabaseService.instance.loadRecentTrackingLog(
      limit: 500,
    );
    if (mounted)
      setState(() {
        _entries = entries;
        _loading = false;
      });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log löschen?'),
        content: const Text(
          'Alle Log-Einträge werden unwiderruflich gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseService.instance.clearTrackingLog();
      await _load();
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'stay_started':
      case 'unknown_stay_started':
        return Colors.green;
      case 'stay_ended':
      case 'stay_switched':
        return Colors.orange;
      case 'halt_known':
        return Colors.teal;
      case 'halt_unknown':
        return Colors.cyan;
      case 'detecting':
        return Colors.blue;
      case 'moving':
        return Colors.grey;
      case 'no_data':
        return Colors.red;
      default:
        return Colors.black54;
    }
  }

  String _formatTs(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}:'
        '${d.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking-Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Log löschen',
            onPressed: _clear,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const Center(child: Text('Keine Log-Einträge vorhanden.'))
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, i) {
                final e = _entries[i];
                final statusChanged = e.prevStatus != e.newStatus;
                return Container(
                  decoration: BoxDecoration(
                    color: statusChanged
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : null,
                    border: Border(
                      left: BorderSide(color: _actionColor(e.action), width: 4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timestamp
                        SizedBox(
                          width: 60,
                          child: Text(
                            _formatTs(e.ts),
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status transition
                        SizedBox(
                          width: 130,
                          child: Text(
                            statusChanged
                                ? '${e.prevStatus}\n→ ${e.newStatus}'
                                : e.newStatus,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: statusChanged
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Metrics
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'S: ${e.shortPts}pts '
                                '${e.shortFull ? '✓full' : '✗full'} '
                                '${e.shortCluster ? '✓cluster' : '✗cluster'}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (e.longPts > 0)
                                Text(
                                  'L: ${e.longPts}pts '
                                  '${e.longFull ? '✓full' : '✗full'} '
                                  '${e.longCluster ? '✓cluster' : '✗cluster'}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              Text(
                                e.placeId != null
                                    ? '${e.action} (place #${e.placeId})'
                                    : e.action,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _actionColor(e.action),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
