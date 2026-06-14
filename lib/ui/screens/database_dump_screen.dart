import 'dart:async';

import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus, XFile;

import '../../services/database_service.dart';

class DatabaseDumpScreen extends StatefulWidget {
  const DatabaseDumpScreen({super.key});

  @override
  State<DatabaseDumpScreen> createState() => _DatabaseDumpScreenState();
}

class _DatabaseDumpScreenState extends State<DatabaseDumpScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  StreamSubscription? _sharingSubscription;

  bool _exporting = false;
  bool _importing = false;
  bool _resetting = false;

  // Last received shared file path
  String? _pendingImportPath;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _initSharingListeners();
  }

  void _initSharingListeners() {
    // File shared while app is running
    _sharingSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((files) {
          if (files.isNotEmpty) {
            setState(() => _pendingImportPath = files.first.path);
            _tabCtrl.animateTo(1);
          }
        });

    // File that launched the app
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty && mounted) {
        setState(() => _pendingImportPath = files.first.path);
        _tabCtrl.animateTo(1);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _sharingSubscription?.cancel();
    super.dispose();
  }

  // ── Dump ──────────────────────────────────────────────────────────────────

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _exportDatabase() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _exporting = true);
    try {
      final path = await DatabaseService.instance.getDatabaseFilePath();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], title: 'Chaos Tours Datenbank'),
      );
    } catch (e) {
      _showError(l10n.exportFailed(e.toString()));
    } finally {
      setState(() => _exporting = false);
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _importDatabase() async {
    final path = _pendingImportPath;
    if (path == null) return;

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dbReplaceTitle),
        content: Text(l10n.dbReplaceContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.replace,
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      await DatabaseService.instance.importDatabaseFile(path);
      if (mounted) {
        setState(() => _pendingImportPath = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importSuccess)),
        );
      }
    } catch (e) {
      _showError(l10n.importFailed(e.toString()));
    } finally {
      setState(() => _importing = false);
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  Future<void> _resetDatabase() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dbResetTitle),
        content: Text(l10n.dbResetContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.reset,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _resetting = true);
    try {
      await DatabaseService.instance.resetAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.resetSuccess)),
        );
      }
    } catch (e) {
      _showError(l10n.resetFailed(e.toString()));
    } finally {
      setState(() => _resetting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.databaseTitle),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(icon: const Icon(Icons.upload_file), text: l10n.tabExport),
            Tab(icon: const Icon(Icons.download_for_offline), text: l10n.tabImport),
            Tab(icon: const Icon(Icons.delete_forever), text: l10n.tabReset),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabCtrl,
          children: [_buildExportTab(), _buildImportTab(), _buildResetTab()],
        ),
      ),
    );
  }

  Widget _buildExportTab() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.storage, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            l10n.exportTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.exportDescription,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _exporting ? null : _exportDatabase,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share),
            label: Text(l10n.shareDatabase),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildImportTab() {
    final l10n = AppLocalizations.of(context)!;
    final hasFile = _pendingImportPath != null;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(
            hasFile ? Icons.check_circle_outline : Icons.folder_open,
            size: 64,
            color: hasFile ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.importTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!hasFile) ...[
            Text(
              l10n.importHowTo,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.importAutoOpenHint,
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              l10n.fileReceived,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Text(
                _pendingImportPath!.split('/').last,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.importOverwriteWarning,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (hasFile)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
              ),
              onPressed: _importing ? null : _importDatabase,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_for_offline),
              label: Text(l10n.importNow),
            )
          else
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.hourglass_empty),
              label: Text(l10n.importWaiting),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  Widget _buildResetTab() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.delete_forever, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            l10n.resetTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.resetDescription,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.resetIrreversibleWarning,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _resetting ? null : _resetDatabase,
            icon: _resetting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_forever),
            label: Text(l10n.deleteAllData),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
