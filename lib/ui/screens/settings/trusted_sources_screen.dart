import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';

import '../../../models/trusted_source.dart';
import '../../../services/database_service.dart';
import '../../../services/settings_service.dart';
import 'trusted_source_edit_sheet.dart';

class TrustedSourcesScreen extends StatefulWidget {
  const TrustedSourcesScreen({super.key});

  @override
  State<TrustedSourcesScreen> createState() => _TrustedSourcesScreenState();
}

class _TrustedSourcesScreenState extends State<TrustedSourcesScreen> {
  static const _pageSize = 50;

  List<TrustedSource> _all = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadNextPage();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _all = [];
      _hasMore = true;
    });
    await DatabaseService.instance.refreshTrustedSources();
    final page = await DatabaseService.instance.loadTrustedSourcesPage(
      0,
      _pageSize,
    );
    if (mounted) {
      setState(() {
        _all = page;
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final page = await DatabaseService.instance.loadTrustedSourcesPage(
      _all.length,
      _pageSize,
    );
    if (mounted) {
      setState(() {
        _all.addAll(page);
        _hasMore = page.length == _pageSize;
        _loadingMore = false;
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
      builder: (_) => TrustedSourceEditSheet(source: ts),
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
      body: SafeArea(
        child: _loading && _all.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _all.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.devices_other,
                      size: 48,
                      color: Colors.grey,
                    ),
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
                controller: _scrollCtrl,
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
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
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
      //trailing: Switch(value: source.trusted, onChanged: (_) => onToggle()),
      trailing: Icon(
        source.trusted ? Icons.check_circle : Icons.cancel,
        color: source.trusted ? Colors.green : Colors.red,
      ),
      onTap: onTap,
    );
  }
}
