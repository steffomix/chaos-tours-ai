import 'package:flutter/material.dart';
import 'package:chaos_tours_ai/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

import '../../models/telegram_connection.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../services/telegram_service.dart';
import '../../utils/unified_widget.dart';

class TelegramConnectionDetailScreen extends StatefulWidget {
  final TelegramConnection? existing;

  const TelegramConnectionDetailScreen({super.key, required this.existing});

  @override
  State<TelegramConnectionDetailScreen> createState() =>
      _TelegramConnectionDetailScreenState();
}

class _TelegramConnectionDetailScreenState
    extends State<TelegramConnectionDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _uuid;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _chatIdCtrl;
  late final TextEditingController _tokenCtrl;
  late final TextEditingController _testMsgCtrl;

  bool _tokenVisible = false;

  bool? _testSuccess;
  String? _testResultMsg;
  bool _isSendingTest = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _uuid = e?.uuid ?? const Uuid().v4();
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _chatIdCtrl = TextEditingController(text: e?.chatId ?? '');
    _tokenCtrl = TextEditingController(
      text: e != null
          ? (SettingsService.instance.getTelegramBotToken(e.uuid) ?? '')
          : '',
    );
    _testMsgCtrl = TextEditingController(text: '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _chatIdCtrl.dispose();
    _tokenCtrl.dispose();
    _testMsgCtrl.dispose();
    super.dispose();
  }

  TelegramConnection _buildConn() => TelegramConnection(
    uuid: _uuid,
    name: _nameCtrl.text.trim(),
    description: _descCtrl.text.trim(),
    chatId: _chatIdCtrl.text.trim(),
  );

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _sendTest() async {
    final l10n = AppLocalizations.of(context)!;
    final msg = _testMsgCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() {
      _isSendingTest = true;
      _testResultMsg = null;
      _testSuccess = null;
    });

    final conn = _buildConn();
    // Temporarily store the token so TelegramService can read it.
    final previousToken =
        SettingsService.instance.getTelegramBotToken(_uuid) ?? '';
    final currentToken = _tokenCtrl.text.trim();
    if (currentToken != previousToken) {
      await SettingsService.instance.setTelegramBotToken(_uuid, currentToken);
    }

    final result = await TelegramService.instance.sendMessage(conn, msg);

    // Restore old token if we changed it only for the test.
    if (currentToken != previousToken) {
      await SettingsService.instance.setTelegramBotToken(
        _uuid,
        previousToken.isEmpty ? null : previousToken,
      );
    }

    if (mounted) {
      setState(() {
        _isSendingTest = false;
        _testSuccess = result.success;
        _testResultMsg = result.success
            ? l10n.telegramTestSent
            : l10n.telegramTestError(result.errorMessage ?? '');
      });
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final conn = _buildConn();

    if (widget.existing == null) {
      await DatabaseService.instance.insertTelegramConnection(conn);
    } else {
      await DatabaseService.instance.updateTelegramConnection(
        conn.copyWith(uuid: widget.existing!.uuid),
      );
    }

    await SettingsService.instance.setTelegramBotToken(
      _uuid,
      _tokenCtrl.text.trim(),
    );

    if (mounted) Navigator.pop(context, true);
  }

  // ── Build helpers ──────────────────────────────────────────────────────────

  Widget _resultText({required bool? success, required String? message}) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: success == true ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? l10n.newTelegramConnection
              : l10n.editTelegramConnection,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: UnifiedWidget(context).saveButton(onPressed: _save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Grundeinstellungen ──────────────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: '${l10n.name} *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: l10n.description,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            // ── Telegram ────────────────────────────────────────────────────
            UnifiedWidget(context).namedDivider('Telegram'),
            TextFormField(
              controller: _chatIdCtrl,
              decoration: InputDecoration(
                labelText: l10n.chatIdLabel,
                hintText: l10n.chatIdHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tokenCtrl,
              decoration: InputDecoration(
                labelText: l10n.botTokenLabel,
                hintText: l10n.botTokenHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _tokenVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _tokenVisible = !_tokenVisible),
                ),
              ),
              obscureText: !_tokenVisible,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? l10n.required : null,
            ),

            // ── Verbindung testen ───────────────────────────────────────────
            UnifiedWidget(context).namedDivider(l10n.telegramSectionTest),
            TextFormField(
              controller: _testMsgCtrl,
              decoration: InputDecoration(
                labelText: l10n.telegramTestMessageHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _isSendingTest
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(l10n.telegramSendTestButton),
                onPressed: _isSendingTest ? null : _sendTest,
              ),
            ),
            _resultText(success: _testSuccess, message: _testResultMsg),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
