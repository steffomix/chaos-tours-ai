import 'package:flutter/material.dart';

import '../../models/activity.dart';
import '../../services/database_service.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  List<Activity> _activities = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final activities = await DatabaseService.instance.loadAllActivities();
    if (mounted) setState(() => _activities = activities);
  }

  Future<void> _add() async {
    final result = await _showEditDialog(null);
    if (result != null) {
      await DatabaseService.instance.insertActivity(result);
      await _load();
    }
  }

  Future<void> _edit(Activity activity) async {
    final result = await _showEditDialog(activity);
    if (result != null) {
      await DatabaseService.instance.updateActivity(result);
      await _load();
    }
  }

  Future<void> _delete(Activity activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tätigkeit löschen?'),
        content: Text('„${activity.name}" wirklich entfernen?'),
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
    if (confirmed == true) {
      await DatabaseService.instance.deleteActivity(activity.uuid);
      await _load();
    }
  }

  Future<Activity?> _showEditDialog(Activity? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');

    return showDialog<Activity>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null ? 'Neue Tätigkeit' : 'Tätigkeit bearbeiten',
        ),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, Activity(uuid: existing?.uuid, name: name));
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tätigkeiten')),
      body: _activities.isEmpty
          ? const Center(child: Text('Noch keine Tätigkeiten vorhanden.'))
          : ListView.builder(
              itemCount: _activities.length,
              itemBuilder: (ctx, i) {
                final a = _activities[i];
                return ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: Text(a.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _edit(a),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(a),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: 'Tätigkeit hinzufügen',
        child: const Icon(Icons.add),
      ),
    );
  }
}
