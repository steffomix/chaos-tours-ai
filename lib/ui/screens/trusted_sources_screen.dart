import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../models/trusted_source.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';

class TrustedSourcesScreen extends StatefulWidget {
  const TrustedSourcesScreen({super.key});

  @override
  State<TrustedSourcesScreen> createState() => _TrustedSourcesScreenState();
}

class _TrustedSourcesScreenState extends State<TrustedSourcesScreen> {
  List<TrustedSource> _all = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await DatabaseService.instance.refreshTrustedSources();
    final list = await DatabaseService.instance.loadAllTrustedSources();
    if (mounted) {
      setState(() {
        _all = list;
        _loading = false;
      });
    }
  }

  Future<void> _toggleTrust(TrustedSource ts) async {
    final l10n = AppLocalizations.of(context)!;
    final makeTrusted = !ts.trusted;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          makeTrusted
              ? l10n.confirmMarkTrustedTitle
              : l10n.confirmMarkUntrustedTitle,
        ),
        content: Text(ts.deviceId),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService.instance.upsertTrustedSource(
        ts.copyWith(trusted: makeTrusted),
      );
      await _refresh();
    }
  }

  Future<void> _showEditSheet(TrustedSource ts) async {
    final result = await showModalBottomSheet<TrustedSource>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TrustedSourceEditSheet(source: ts),
    );
    if (result != null) {
      await DatabaseService.instance.upsertTrustedSource(result);
      await _refresh();
    }
  }

  Widget _sectionHeader(String title) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ownId = SettingsService.instance.deviceId;

    final trusted = _all.where((t) => t.trusted).toList();
    final known = _all.where((t) => !t.trusted).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trustedSourcesTitle),
        actions: [
          if (_loading)
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
              icon: const Icon(Icons.refresh),
              tooltip: l10n.refreshTrustedSources,
              onPressed: _refresh,
            ),
        ],
      ),
      body: _loading && _all.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _all.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.devices_other, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(l10n.noTrustedSources, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.refreshTrustedSources),
                    onPressed: _refresh,
                  ),
                ],
              ),
            )
          : ListView(
              children: [
                if (trusted.isNotEmpty) ...[
                  _sectionHeader(l10n.trustedDevicesSection),
                  ...trusted.map(
                    (ts) => _DeviceTile(
                      source: ts,
                      isOwn: ts.deviceId == ownId,
                      onToggle: () => _toggleTrust(ts),
                      onTap: () => _showEditSheet(ts),
                    ),
                  ),
                ],
                if (known.isNotEmpty) ...[
                  _sectionHeader(l10n.knownDevicesSection),
                  ...known.map(
                    (ts) => _DeviceTile(
                      source: ts,
                      isOwn: ts.deviceId == ownId,
                      onToggle: () => _toggleTrust(ts),
                      onTap: () => _showEditSheet(ts),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

// ── Single device tile ────────────────────────────────────────────────────────

class _DeviceTile extends StatelessWidget {
  final TrustedSource source;
  final bool isOwn;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.source,
    required this.isOwn,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        source.deviceId,
        style: isOwn ? const TextStyle(fontWeight: FontWeight.bold) : null,
      ),
      subtitle: source.note.isNotEmpty ? Text(source.note) : null,
      trailing: Switch(value: source.trusted, onChanged: (_) => onToggle()),
      onTap: onTap,
    );
  }
}

// ── Edit sheet (metadata only) ────────────────────────────────────────────────

class _TrustedSourceEditSheet extends StatefulWidget {
  final TrustedSource source;
  const _TrustedSourceEditSheet({required this.source});

  @override
  State<_TrustedSourceEditSheet> createState() =>
      _TrustedSourceEditSheetState();
}

class _TrustedSourceEditSheetState extends State<_TrustedSourceEditSheet> {
  late final TextEditingController _noteCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _noteCtrl = TextEditingController(text: s.note);
    _urlCtrl = TextEditingController(text: s.url);
    _emailCtrl = TextEditingController(text: s.email);
    _addressCtrl = TextEditingController(text: s.address);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _urlCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final result = widget.source.copyWith(
      note: _noteCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.editTrustedSource,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              widget.source.deviceId,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: l10n.notes,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.email,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: l10n.address,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: Text(l10n.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
