import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/telegram_connection.dart';
import '../../services/database_service.dart';

class TelegramConnectionsScreen extends StatefulWidget {
  const TelegramConnectionsScreen({super.key});

  @override
  State<TelegramConnectionsScreen> createState() =>
      _TelegramConnectionsScreenState();
}

class _TelegramConnectionsScreenState extends State<TelegramConnectionsScreen> {
  List<TelegramConnection> _connections = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseService.instance.loadAllTelegramConnections();
    if (mounted) setState(() => _connections = list);
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> _add() async {
    final result = await _showEditDialog(null);
    if (result != null) {
      await DatabaseService.instance.insertTelegramConnection(result);
      await _load();
    }
  }

  Future<void> _edit(TelegramConnection conn) async {
    final result = await _showEditDialog(conn);
    if (result != null) {
      await DatabaseService.instance.updateTelegramConnection(
        result.copyWith(uuid: conn.uuid),
      );
      await _load();
    }
  }

  Future<void> _delete(TelegramConnection conn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verbindung löschen?'),
        content: Text('„${conn.name}" wird unwiderruflich gelöscht.'),
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
      await DatabaseService.instance.softDeleteTelegramConnection(conn.uuid);
      await _load();
    }
  }

  // ── Edit Dialog ────────────────────────────────────────────────────────────

  Future<TelegramConnection?> _showEditDialog(
    TelegramConnection? existing,
  ) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final chatIdCtrl = TextEditingController(text: existing?.chatId ?? '');
    final tokenCtrl = TextEditingController(text: existing?.botToken ?? '');
    final formKey = GlobalKey<FormState>();
    bool tokenVisible = false;

    return showDialog<TelegramConnection>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(
            existing == null
                ? 'Neue Telegram-Verbindung'
                : 'Verbindung bearbeiten',
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
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Beschreibung',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: chatIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Chat-ID oder Kanalname *',
                      hintText: '-1001234567890  oder  @meinkanal',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: tokenCtrl,
                    decoration: InputDecoration(
                      labelText: 'Bot-Token *',
                      hintText: '123456:ABC-DEF…',
                      suffixIcon: IconButton(
                        icon: Icon(
                          tokenVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setDlgState(() => tokenVisible = !tokenVisible),
                      ),
                    ),
                    obscureText: !tokenVisible,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
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
                  TelegramConnection(
                    uuid: existing?.uuid,
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    chatId: chatIdCtrl.text.trim(),
                    botToken: tokenCtrl.text.trim(),
                  ),
                );
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telegram-Verbindungen')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: _connections.isEmpty
          ? const Center(
              child: Text('Noch keine Telegram-Verbindungen vorhanden.'),
            )
          : ListView.builder(
              itemCount: _connections.length,
              itemBuilder: (ctx, i) {
                final c = _connections[i];
                final url = c.telegramUrl;
                return ListTile(
                  leading: const Icon(Icons.send),
                  title: Text(c.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.description.isNotEmpty)
                        Text(
                          c.description,
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (url != null)
                        GestureDetector(
                          onTap: () => launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Text(
                            url,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(ctx).colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        )
                      else
                        Text(c.chatId, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _edit(c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _delete(c),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
