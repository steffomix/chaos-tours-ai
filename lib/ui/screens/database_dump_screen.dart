import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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

  // Dump tab
  String? _dumpText;
  bool _dumpLoading = false;

  // Import tab
  final _importCtrl = TextEditingController();
  bool _clearFirst = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _importCtrl.dispose();
    super.dispose();
  }

  // ── Dump ──────────────────────────────────────────────────────────────────

  Future<void> _generateDump() async {
    setState(() => _dumpLoading = true);
    try {
      final dump = await DatabaseService.instance.generateDump();
      setState(() => _dumpText = dump);
    } catch (e) {
      _showError('Dump fehlgeschlagen: $e');
    } finally {
      setState(() => _dumpLoading = false);
    }
  }

  Future<void> _copyToClipboard() async {
    if (_dumpText == null) return;
    await Clipboard.setData(ClipboardData(text: _dumpText!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dump in Zwischenablage kopiert')),
      );
    }
  }

  Future<void> _shareDump() async {
    if (_dumpText == null) return;
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/chaos_tours_dump_$ts.sql');
    await file.writeAsString(_dumpText!);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], title: 'Chaos Tours DB Dump'),
    );
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _importCtrl.text = data!.text!;
    }
  }

  Future<void> _importDump() async {
    final sql = _importCtrl.text.trim();
    if (sql.isEmpty) {
      _showError('Kein SQL-Text zum Importieren vorhanden.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dump importieren?'),
        content: Text(
          _clearFirst
              ? 'Alle vorhandenen Daten werden gelöscht und durch den Dump ersetzt.\n\nFortfahren?'
              : 'Vorhandene Zeilen werden überschrieben (INSERT OR REPLACE).\nNicht im Dump enthaltene Zeilen bleiben erhalten.\n\nFortfahren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Importieren',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      await DatabaseService.instance.importDump(sql, clearFirst: _clearFirst);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dump erfolgreich importiert')),
        );
        _importCtrl.clear();
      }
    } catch (e) {
      _showError('Import fehlgeschlagen: $e');
    } finally {
      setState(() => _importing = false);
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
        title: const Text('Datenbank-Dump'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.download), text: 'Dump erstellen'),
            Tab(icon: Icon(Icons.upload), text: 'Importieren'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildDumpTab(), _buildImportTab()],
      ),
    );
  }

  Widget _buildDumpTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _dumpLoading ? null : _generateDump,
                  icon: _dumpLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Dump generieren'),
                ),
              ),
              if (_dumpText != null) ...[
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _copyToClipboard,
                  tooltip: 'In Zwischenablage kopieren',
                  icon: const Icon(Icons.copy),
                ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  onPressed: _shareDump,
                  tooltip: 'Teilen',
                  icon: const Icon(Icons.share),
                ),
              ],
            ],
          ),
        ),
        if (_dumpText != null)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: SelectableText(
                    _dumpText!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: Center(
              child: Text(
                'Dump noch nicht generiert.',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImportTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste),
                  label: const Text('Aus Zwischenablage einfügen'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: TextField(
              controller: _importCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              decoration: InputDecoration(
                hintText: 'SQL-Dump hier einfügen …',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vorhandene Daten vorher löschen'),
                subtitle: const Text(
                  'Alle Tabellen werden geleert, bevor der Dump eingespielt wird.',
                  style: TextStyle(fontSize: 12),
                ),
                value: _clearFirst,
                onChanged: (v) => setState(() => _clearFirst = v),
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                ),
                onPressed: _importing ? null : _importDump,
                icon: _importing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload),
                label: const Text('Dump laden'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
