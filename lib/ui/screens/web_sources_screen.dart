import 'package:flutter/material.dart';

import '../../models/web_source.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';

class WebSourcesScreen extends StatefulWidget {
  const WebSourcesScreen({super.key});

  @override
  State<WebSourcesScreen> createState() => _WebSourcesScreenState();
}

class _WebSourcesScreenState extends State<WebSourcesScreen> {
  List<WebSource> _sources = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseService.instance.loadAllWebSources();
    if (mounted) setState(() => _sources = list);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> _add() async {
    final result = await _showEditDialog(null);
    if (result != null) {
      final devId = await SyncService.instance.deviceId;
      await DatabaseService.instance.insertWebSource(result, deviceId: devId);
      await _load();
    }
  }

  Future<void> _edit(WebSource source) async {
    final result = await _showEditDialog(source);
    if (result != null) {
      final devId = await SyncService.instance.deviceId;
      await DatabaseService.instance.updateWebSource(
        result.copyWith(id: source.id),
        deviceId: devId,
      );
      await _load();
    }
  }

  Future<void> _delete(WebSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quelle löschen?'),
        content: Text('„${source.name}" wird unwiderruflich gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.instance.softDeleteWebSource(source.id!);
      await _load();
    }
  }

  Future<void> _importPlaces(WebSource source) async {
    setState(() => _loading = true);
    try {
      final result = await SyncService.instance.importFromWebSource(source);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? '${result.pulled} Orte importiert'
                : 'Fehler: ${result.errorMessage}',
          ),
          backgroundColor: result.success ? null : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Dialog ────────────────────────────────────────────────────────────────

  Future<WebSource?> _showEditDialog(WebSource? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    final apiKeyCtrl = TextEditingController(text: existing?.apiKey ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final experienceCtrl = TextEditingController(
      text: existing?.experience ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<WebSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Neue Quelle' : 'Quelle bearbeiten'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    hintText: 'http://192.168.1.10:8000',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: apiKeyCtrl,
                  decoration: const InputDecoration(labelText: 'API-Key'),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notizen'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: experienceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Erfahrungsberichte',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(
                ctx,
                WebSource(
                  name: nameCtrl.text.trim(),
                  url: urlCtrl.text.trim(),
                  apiKey: apiKeyCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                  experience: experienceCtrl.text.trim(),
                ),
              );
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    urlCtrl.dispose();
    apiKeyCtrl.dispose();
    notesCtrl.dispose();
    experienceCtrl.dispose();
    return result;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Web-Quellen'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: 'Quelle hinzufügen',
        child: const Icon(Icons.add),
      ),
      body: _sources.isEmpty
          ? const Center(
              child: Text(
                'Keine Web-Quellen vorhanden.\nTippe + um eine hinzuzufügen.',
              ),
            )
          : ListView.builder(
              itemCount: _sources.length,
              itemBuilder: (_, i) {
                final src = _sources[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.public),
                    title: Text(src.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          src.url,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (src.notes.isNotEmpty)
                          Text(
                            src.notes,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<_SourceAction>(
                      onSelected: (action) {
                        switch (action) {
                          case _SourceAction.edit:
                            _edit(src);
                          case _SourceAction.import:
                            _importPlaces(src);
                          case _SourceAction.delete:
                            _delete(src);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _SourceAction.import,
                          child: ListTile(
                            leading: Icon(Icons.download),
                            title: Text('Orte importieren'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _SourceAction.edit,
                          child: ListTile(
                            leading: Icon(Icons.edit),
                            title: Text('Bearbeiten'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _SourceAction.delete,
                          child: ListTile(
                            leading: Icon(Icons.delete),
                            title: Text('Löschen'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showDetails(src),
                  ),
                );
              },
            ),
    );
  }

  void _showDetails(WebSource src) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(src.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(src.url, style: const TextStyle(color: Colors.blue)),
            if (src.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Notizen',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(src.notes),
            ],
            if (src.experience.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Erfahrungsbericht',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(src.experience),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _importPlaces(src);
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Orte importieren'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

enum _SourceAction { edit, import, delete }
