import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.taskDeleteTitle),
        content: Text(l10n.taskDeleteContent(activity.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
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
    final l10n = AppLocalizations.of(context)!;

    return showDialog<Activity>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? l10n.newTask : l10n.editTask),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: l10n.name,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, Activity(uuid: existing?.uuid, name: name));
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.activitiesScreenTitle)),
      body: _activities.isEmpty
          ? Center(child: Text(l10n.noActivitiesYet))
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
        tooltip: l10n.addTaskTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }
}
