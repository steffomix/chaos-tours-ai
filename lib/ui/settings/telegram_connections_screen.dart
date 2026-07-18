import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/telegram_connection.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../utils/custom_icons.dart';
import '../../utils/unified_widget.dart';

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
      await DatabaseService.instance.insertTelegramConnection(result.$1);
      await SettingsService.instance.setTelegramBotToken(
        result.$1.uuid,
        result.$2,
      );
      await _load();
    }
  }

  Future<void> _edit(TelegramConnection conn) async {
    final result = await _showEditDialog(conn);
    if (result != null) {
      final updated = result.$1.copyWith(uuid: conn.uuid);
      await DatabaseService.instance.updateTelegramConnection(updated);
      await SettingsService.instance.setTelegramBotToken(
        updated.uuid,
        result.$2,
      );
      await _load();
    }
  }

  Future<void> _delete(TelegramConnection conn) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.connectionDeleteTitle),
        content: Text(l10n.connectionDeleteContent(conn.name)),
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
      await DatabaseService.instance.softDeleteTelegramConnection(conn.uuid);
      await _load();
    }
  }

  // ── Edit Dialog ────────────────────────────────────────────────────────────

  Future<(TelegramConnection, String)?> _showEditDialog(
    TelegramConnection? existing,
  ) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final chatIdCtrl = TextEditingController(text: existing?.chatId ?? '');
    final tokenCtrl = TextEditingController(
      text: existing != null
          ? (SettingsService.instance.getTelegramBotToken(existing.uuid) ?? '')
          : '',
    );
    final formKey = GlobalKey<FormState>();
    bool tokenVisible = false;

    return showDialog<(TelegramConnection, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final l10n = AppLocalizations.of(ctx)!;
          return AlertDialog(
            title: Text(
              existing == null
                  ? l10n.newTelegramConnection
                  : l10n.editTelegramConnection,
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
                      controller: descCtrl,
                      decoration: InputDecoration(labelText: l10n.description),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: chatIdCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.chatIdLabel,
                        hintText: l10n.chatIdHint,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: tokenCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.botTokenLabel,
                        hintText: l10n.botTokenHint,
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
                          v == null || v.trim().isEmpty ? l10n.required : null,
                    ),
                  ],
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: UnifiedWidget(context).saveAndCancelButtonsList(
              onSavePressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(ctx, (
                  TelegramConnection(
                    uuid: existing?.uuid,
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    chatId: chatIdCtrl.text.trim(),
                  ),
                  tokenCtrl.text.trim(),
                ));
              },
              onCancelPressed: () => Navigator.pop(ctx),
            ),
          );
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.telegramConnectionsTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: _connections.isEmpty
          ? Center(child: Text(l10n.noTelegramConnections))
          : ListView.builder(
              itemCount: _connections.length,
              itemBuilder: (ctx, i) {
                final c = _connections[i];
                final url = c.telegramUrl;
                return ListTile(
                  leading: telegramIcon(),
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
