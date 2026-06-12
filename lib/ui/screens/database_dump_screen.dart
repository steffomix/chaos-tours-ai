import 'dart:async';

import 'package:flutter/material.dart';
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
    setState(() => _exporting = true);
    try {
      final path = await DatabaseService.instance.getDatabaseFilePath();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], title: 'Chaos Tours Datenbank'),
      );
    } catch (e) {
      _showError('Export fehlgeschlagen: $e');
    } finally {
      setState(() => _exporting = false);
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _importDatabase() async {
    final path = _pendingImportPath;
    if (path == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datenbank ersetzen?'),
        content: const Text(
          'Die aktuelle Datenbank wird vollständig durch die geteilte Datei ersetzt.\n\nAlle vorhandenen Daten gehen verloren.\n\nFortfahren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Ersetzen',
              style: TextStyle(color: Colors.orange),
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
          const SnackBar(content: Text('Datenbank erfolgreich importiert')),
        );
      }
    } catch (e) {
      _showError('Import fehlgeschlagen: $e');
    } finally {
      setState(() => _importing = false);
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  Future<void> _resetDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datenbank zurücksetzen?'),
        content: const Text(
          'Alle Daten werden unwiderruflich gelöscht. Die Datenbankstruktur bleibt erhalten.\n\nFortfahren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Zurücksetzen',
              style: TextStyle(color: Colors.red),
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
          const SnackBar(content: Text('Datenbank zurückgesetzt')),
        );
      }
    } catch (e) {
      _showError('Zurücksetzen fehlgeschlagen: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Datenbank'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file), text: 'Exportieren'),
            Tab(icon: Icon(Icons.download_for_offline), text: 'Importieren'),
            Tab(icon: Icon(Icons.delete_forever), text: 'Zurücksetzen'),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.storage, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Datenbank exportieren',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Die SQLite-Datenbankdatei wird direkt geteilt. Sie kann als Backup gespeichert oder auf ein anderes Gerät übertragen werden.',
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
            label: const Text('Datenbank teilen'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildImportTab() {
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
          const Text(
            'Datenbank importieren',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!hasFile) ...[
            const Text(
              'So importierst du eine Datenbank:\n\n'
              '1. Öffne die Dateien-App\n'
              '2. Halte die .db-Datei gedrückt\n'
              '3. Tippe auf „Teilen"\n'
              '4. Wähle „Chaos Tours" aus der Liste',
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
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Diese App öffnet sich automatisch, wenn du eine Datei hierher teilst.',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Datei empfangen:',
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
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alle vorhandenen Daten werden überschrieben.',
                      style: TextStyle(color: Colors.orange),
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
              label: const Text('Jetzt importieren'),
            )
          else
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.hourglass_empty),
              label: const Text('Warte auf geteilte Datei …'),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildResetTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.delete_forever, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Datenbank zurücksetzen',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Alle Daten werden unwiderruflich gelöscht. Die Datenbankstruktur bleibt erhalten.',
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
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Diese Aktion kann nicht rückgängig gemacht werden.',
                    style: TextStyle(color: Colors.red),
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
            label: const Text('Alle Daten löschen'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
