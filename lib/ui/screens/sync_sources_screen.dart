import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/sync_source.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';

class SyncSourcesScreen extends StatefulWidget {
  const SyncSourcesScreen({super.key});

  @override
  State<SyncSourcesScreen> createState() => _SyncSourcesScreenState();
}

class _SyncSourcesScreenState extends State<SyncSourcesScreen> {
  List<SyncSource> _sources = [];
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseService.instance.loadAllSyncSources();
    if (mounted) setState(() => _sources = list);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> _add() async {
    final result = await _showEditDialog(null);
    if (result != null) {
      final devId = await SyncService.instance.deviceId;
      await DatabaseService.instance.insertSyncSource(result, deviceId: devId);
      await _load();
    }
  }

  Future<void> _edit(SyncSource source) async {
    final result = await _showEditDialog(source);
    if (result != null) {
      final devId = await SyncService.instance.deviceId;
      await DatabaseService.instance.updateSyncSource(
        result.copyWith(id: source.id),
        deviceId: devId,
      );
      await _load();
    }
  }

  Future<void> _delete(SyncSource source) async {
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
      final devId = await SyncService.instance.deviceId;
      await DatabaseService.instance.softDeleteSyncSource(
        source.id!,
        deviceId: devId,
      );
      await _load();
    }
  }

  Future<void> _syncNow(SyncSource source) async {
    // Warn about backup first.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Synchronisieren'),
        content: const Text(
          '⚠️ Es wird dringend empfohlen, vor der Synchronisation eine '
          'Sicherheitskopie der Datenbank zu exportieren '
          '(Einstellungen → Datenbank-Dump).\n\n'
          'Jetzt synchronisieren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Synchronisieren'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _syncing = true);
    try {
      final result = await SyncService.instance.syncWithSource(source);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? '${result.pulled} empfangen, ${result.pushed} gesendet'
                : 'Fehler: ${result.errorMessage}',
          ),
          backgroundColor: result.success ? null : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _syncAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Alle synchronisieren'),
        content: const Text(
          '⚠️ Es wird dringend empfohlen, vor der Synchronisation eine '
          'Sicherheitskopie der Datenbank zu exportieren '
          '(Einstellungen → Datenbank-Dump).\n\n'
          'Mit allen aktiven Sync-Quellen synchronisieren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Synchronisieren'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _syncing = true);
    try {
      final results = await SyncService.instance.syncAll();
      if (!mounted) return;
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine aktiven Sync-Quellen konfiguriert'),
          ),
        );
        return;
      }
      final ok = results.where((r) => r.success).length;
      final fail = results.length - ok;
      final totalPulled = results.fold(0, (a, r) => a + r.pulled);
      final totalPushed = results.fold(0, (a, r) => a + r.pushed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$ok Quelle(n) OK ($totalPulled empfangen, $totalPushed gesendet)'
            '${fail > 0 ? ', $fail Fehler' : ''}',
          ),
          backgroundColor: fail > 0 ? Colors.orange : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // ── Edit Dialog ────────────────────────────────────────────────────────────

  Future<SyncSource?> _showEditDialog(SyncSource? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final syncUrlCtrl = TextEditingController(text: existing?.syncUrl ?? '');
    final apiKeyCtrl = TextEditingController(text: existing?.apiKey ?? '');
    final infoUrlCtrl = TextEditingController(text: existing?.infoUrl ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final formKey = GlobalKey<FormState>();
    bool apiKeyVisible = false;

    final result = await showDialog<SyncSource>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            existing == null ? 'Neue Sync-Quelle' : 'Quelle bearbeiten',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: syncUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sync-Adresse *',
                      hintText: 'http://192.168.1.10:8000',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: apiKeyCtrl,
                    decoration: InputDecoration(
                      labelText: 'API-Key',
                      suffixIcon: IconButton(
                        icon: Icon(
                          apiKeyVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setDlgState(() => apiKeyVisible = !apiKeyVisible),
                      ),
                    ),
                    obscureText: !apiKeyVisible,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: infoUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Info-URL (optional)',
                      hintText: 'https://example.com',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Beschreibung',
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
                  (existing ?? SyncSource(name: '', syncUrl: '')).copyWith(
                    name: nameCtrl.text.trim(),
                    syncUrl: syncUrlCtrl.text.trim(),
                    apiKey: apiKeyCtrl.text.trim(),
                    infoUrl: infoUrlCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                  ),
                );
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );

    return result;
  }

  // ── Sync Options Dialog ────────────────────────────────────────────────────

  Future<void> _editSyncOptions(SyncSource source) async {
    // Create a mutable copy of options.
    var opts = source.syncOptions;

    final labels = {
      'place_groups': 'Ortsgruppen',
      'saved_places': 'Orte',
      'persons': 'Personen',
      'activities': 'Tätigkeiten',
      'stays': 'Aufenthalte',
      'stay_persons': 'Aufenthalts-Personen',
      'stay_activities': 'Aufenthalts-Tätigkeiten',
      'aktivitaeten': 'Aktivitäten',
      'sync_sources': 'Sync-Quellen',
      'place_experiences': 'Orts-Erfahrungen',
    };

    final saved = await showDialog<SyncSourceOptions>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Sync-Optionen'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚠️ Vor dem Aktivieren von Bearbeiten/Löschen empfiehlt sich '
                  'ein Datenbank-Export als Sicherheitskopie.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    SizedBox(width: 130),
                    Expanded(
                      child: Center(
                        child: Text('Einfügen', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Bearbeiten',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text('Löschen', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: SyncSourceOptions.allTables.map((table) {
                        final tableOpts = opts.forTable(table);
                        return Row(
                          children: [
                            SizedBox(
                              width: 130,
                              child: Text(
                                labels[table] ?? table,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: Checkbox(
                                value: tableOpts.insert,
                                onChanged: (v) => setDlgState(() {
                                  opts = opts.copyWithTable(
                                    table,
                                    tableOpts.copyWith(insert: v ?? false),
                                  );
                                }),
                              ),
                            ),
                            Expanded(
                              child: Checkbox(
                                value: tableOpts.update,
                                onChanged: (v) => setDlgState(() {
                                  opts = opts.copyWithTable(
                                    table,
                                    tableOpts.copyWith(update: v ?? false),
                                  );
                                }),
                              ),
                            ),
                            Expanded(
                              child: Checkbox(
                                value: tableOpts.delete,
                                onChanged: (v) => setDlgState(() {
                                  opts = opts.copyWithTable(
                                    table,
                                    tableOpts.copyWith(delete: v ?? false),
                                  );
                                }),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, opts),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );

    if (saved != null) {
      final devId = await SyncService.instance.deviceId;
      await DatabaseService.instance.updateSyncSource(
        source.copyWith(syncOptions: saved),
        deviceId: devId,
      );
      await _load();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync-Quellen'),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Alle synchronisieren',
              onPressed: _sources.isEmpty ? null : _syncAll,
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
                'Keine Sync-Quellen vorhanden.\nTippe + um eine hinzuzufügen.',
                textAlign: TextAlign.center,
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
                    leading: const Icon(Icons.sync),
                    title: Text(src.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          src.syncUrl,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (src.description.isNotEmpty)
                          Text(
                            src.description,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        // Summary of active options.
                        Text(
                          _optionsSummary(src.syncOptions),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<_SourceAction>(
                      onSelected: (action) {
                        switch (action) {
                          case _SourceAction.sync:
                            _syncNow(src);
                          case _SourceAction.options:
                            _editSyncOptions(src);
                          case _SourceAction.edit:
                            _edit(src);
                          case _SourceAction.delete:
                            _delete(src);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _SourceAction.sync,
                          child: ListTile(
                            leading: Icon(Icons.sync),
                            title: Text('Jetzt synchronisieren'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _SourceAction.options,
                          child: ListTile(
                            leading: Icon(Icons.tune),
                            title: Text('Sync-Optionen'),
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

  String _optionsSummary(SyncSourceOptions opts) {
    final active = opts.tables.entries
        .where((e) => e.value.anyEnabled)
        .map((e) => e.key.replaceAll('_', ' '))
        .take(3)
        .join(', ');
    final total = opts.tables.values.where((o) => o.anyEnabled).length;
    if (total == 0) return 'Keine Sync-Optionen aktiv';
    if (total > 3) return '$active … ($total Tabellen aktiv)';
    return active;
  }

  void _showDetails(SyncSource src) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SyncSourceDetailsSheet(source: src),
    );
  }
}

enum _SourceAction { sync, options, edit, delete }

// ── Details sheet ─────────────────────────────────────────────────────────────

class _SyncSourceDetailsSheet extends StatelessWidget {
  final SyncSource source;
  const _SyncSourceDetailsSheet({required this.source});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Text(source.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _row(Icons.sync, 'Sync-Adresse', source.syncUrl),
            if (source.infoUrl.isNotEmpty)
              InkWell(
                onTap: () => launchUrl(Uri.parse(source.infoUrl)),
                child: _row(
                  Icons.link,
                  'Info-URL',
                  source.infoUrl,
                  color: Colors.blue,
                ),
              ),
            if (source.description.isNotEmpty)
              _row(Icons.notes, 'Beschreibung', source.description),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Aktive Sync-Optionen',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...SyncSourceOptions.allTables.map((t) {
              final opts = source.syncOptions.forTable(t);
              if (!opts.anyEnabled) return const SizedBox.shrink();
              final parts = [
                if (opts.insert) 'Einfügen',
                if (opts.update) 'Bearbeiten',
                if (opts.delete) 'Löschen',
              ];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(t, style: const TextStyle(fontSize: 13)),
                    ),
                    Text(
                      parts.join(' · '),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(value, style: TextStyle(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
