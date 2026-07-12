import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/sync_source.dart';
import '../../models/sync_source_experience.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../utils/unified_widget.dart';
import '../widgets/sync_options_dialog.dart';

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
      final devId = SyncService.instance.deviceId;
      await DatabaseService.instance.insertSyncSource(result, deviceId: devId);
      await _load();
    }
  }

  Future<void> _edit(SyncSource source) async {
    final result = await _showEditDialog(source);
    if (result != null) {
      final devId = SyncService.instance.deviceId;
      await DatabaseService.instance.updateSyncSource(
        result.copyWith(uuid: source.uuid),
        deviceId: devId,
      );
      await _load();
    }
  }

  Future<void> _delete(SyncSource source) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sourceDeleteTitle),
        content: Text(l10n.sourceDeleteContent(source.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final devId = SyncService.instance.deviceId;
      await DatabaseService.instance.softDeleteSyncSource(
        source.uuid,
        deviceId: devId,
      );
      await _load();
    }
  }

  Future<void> _syncNow(SyncSource source) async {
    final l10n = AppLocalizations.of(context)!;
    // Warn about backup first.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.syncTitle),
        content: Text(l10n.syncWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.synchronize),
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
                ? l10n.syncResultSuccess(result.pulled, result.pushed)
                : l10n.syncError(result.errorMessage ?? ''),
          ),
          backgroundColor: result.success ? null : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _syncAll() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.syncAllTitle),
        content: Text(l10n.syncAllWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.synchronize),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.noActiveSyncSources)));
        return;
      }
      final ok = results.where((r) => r.success).length;
      final fail = results.length - ok;
      final totalPulled = results.fold(0, (a, r) => a + r.pulled);
      final totalPushed = results.fold(0, (a, r) => a + r.pushed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fail > 0
                ? l10n.syncAllResultWithErrors(
                    ok,
                    totalPulled,
                    totalPushed,
                    fail,
                  )
                : l10n.syncAllResult(ok, totalPulled, totalPushed),
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
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, setDlgState) => AlertDialog(
            title: Text(
              existing == null ? l10n.newSyncSource : l10n.editSyncSource,
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(labelText: '${l10n.name} *'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: syncUrlCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.syncAddress,
                        hintText: l10n.syncAddressHint,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: apiKeyCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.apiKey,
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
                      decoration: InputDecoration(
                        labelText: l10n.infoUrlOptional,
                        hintText: l10n.infoUrlHint,
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descCtrl,
                      decoration: InputDecoration(labelText: l10n.description),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: UnifiedWidget(context).saveAndCancelButtonsList(
              onSavePressed: () {
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
              onCancelPressed: () => Navigator.pop(ctx),
            ),
          ),
        );
      },
    );

    return result;
  }

  // ── Sync Options Dialog ────────────────────────────────────────────────────

  Future<void> _editSyncOptions(SyncSource source) async {
    final saved = await showSyncOptionsDialog(context, source.syncOptions);
    if (saved != null) {
      final devId = SyncService.instance.deviceId;
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncSourcesTitle),
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
              tooltip: l10n.syncAllTooltip,
              onPressed: _sources.isEmpty ? null : _syncAll,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: l10n.addSourceTooltip,
        child: const Icon(Icons.add),
      ),
      body: _sources.isEmpty
          ? Center(child: Text(l10n.noSyncSources, textAlign: TextAlign.center))
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
                          case _SourceAction.reset:
                            DatabaseService.instance.updateSyncSource(
                              src.copyWith(lastSyncMs: 0),
                            );
                        }
                      },
                      itemBuilder: (ctx) {
                        final l10n = AppLocalizations.of(ctx)!;
                        return [
                          PopupMenuItem(
                            value: _SourceAction.sync,
                            child: ListTile(
                              leading: const Icon(Icons.sync),
                              title: Text(l10n.syncNow),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: _SourceAction.reset,
                            child: ListTile(
                              leading: const Icon(Icons.timer_off),
                              title: Text(l10n.reset),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: _SourceAction.options,
                            child: ListTile(
                              leading: const Icon(Icons.tune),
                              title: Text(l10n.syncOptionsMenu),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: _SourceAction.edit,
                            child: ListTile(
                              leading: const Icon(Icons.edit),
                              title: Text(l10n.edit),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: _SourceAction.delete,
                            child: ListTile(
                              leading: const Icon(Icons.delete),
                              title: Text(l10n.delete),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ];
                      },
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
    if (total == 0) return AppLocalizations.of(context)!.noSyncOptions;
    if (total > 3) {
      return '$active … (${AppLocalizations.of(context)!.tablesActive(total)})';
    }
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

enum _SourceAction { sync, options, edit, delete, reset }

// ── Details sheet ─────────────────────────────────────────────────────────────

class _SyncSourceDetailsSheet extends StatefulWidget {
  final SyncSource source;
  const _SyncSourceDetailsSheet({required this.source});

  @override
  State<_SyncSourceDetailsSheet> createState() =>
      _SyncSourceDetailsSheetState();
}

class _SyncSourceDetailsSheetState extends State<_SyncSourceDetailsSheet> {
  List<SyncSourceExperience> _experiences = [];

  @override
  void initState() {
    super.initState();
    _loadExperiences();
  }

  Future<void> _loadExperiences() async {
    final list = await DatabaseService.instance.loadExperiencesForSyncSource(
      widget.source.uuid,
    );
    if (mounted) setState(() => _experiences = list);
  }

  Future<void> _addExperience() async {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addExperience),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.experienceHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: UnifiedWidget(context).saveAndCancelButtonsList(
          onSavePressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          onCancelPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
    if (text == null || text.isEmpty) return;
    final devId = SyncService.instance.deviceId;
    await DatabaseService.instance.insertSyncSourceExperience(
      SyncSourceExperience(syncSourceUuid: widget.source.uuid, text: text),
      deviceId: devId,
    );
    await _loadExperiences();
  }

  Future<void> _deleteExperience(SyncSourceExperience exp) async {
    final devId = SyncService.instance.deviceId;
    await DatabaseService.instance.softDeleteSyncSourceExperience(
      exp.uuid,
      deviceId: devId,
    );
    await _loadExperiences();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Text(
              widget.source.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _row(Icons.sync, l10n.syncAddressLabel, widget.source.syncUrl),
            if (widget.source.infoUrl.isNotEmpty)
              InkWell(
                onTap: () => launchUrl(Uri.parse(widget.source.infoUrl)),
                child: _row(
                  Icons.link,
                  l10n.infoUrlLabel,
                  widget.source.infoUrl,
                  color: Colors.blue,
                ),
              ),
            if (widget.source.description.isNotEmpty)
              _row(Icons.notes, l10n.description, widget.source.description),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              l10n.activeSyncOptions,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...SyncSourceOptions.allTables.map((t) {
              final opts = widget.source.syncOptions.forTable(t);
              if (!opts.anyEnabled) return const SizedBox.shrink();
              final parts = [
                if (opts.insert) l10n.insert,
                if (opts.update) l10n.edit,
                if (opts.delete) l10n.delete,
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
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.experiencesTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: l10n.addExperience,
                  onPressed: _addExperience,
                ),
              ],
            ),
            if (_experiences.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.noExperiences,
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            else
              ..._experiences.map(
                (exp) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(exp.text),
                    subtitle: Text(
                      _fmtDate(exp.createdAt),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _deleteExperience(exp),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
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
