import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/telegram_connection.dart';

class TelegramSendResult {
  final bool success;
  final String? errorMessage;

  /// The Telegram message_id (as String) when a message was sent successfully.
  final String? messageId;

  const TelegramSendResult({
    required this.success,
    this.errorMessage,
    this.messageId,
  });
}

/// Sends messages via the Telegram Bot API.
class TelegramService {
  TelegramService._();
  static final TelegramService instance = TelegramService._();

  static const _baseUrl = 'https://api.telegram.org';

  /// Sends [text] (Markdown V2 parse mode) to [connection].
  Future<TelegramSendResult> sendMessage(
    TelegramConnection connection,
    String text,
  ) async {
    final token = connection.botToken.trim();
    final chatId = connection.chatId.trim();
    if (token.isEmpty || chatId.isEmpty) {
      return const TelegramSendResult(
        success: false,
        errorMessage: 'Bot-Token oder Chat-ID fehlt',
      );
    }

    final uri = Uri.parse('$_baseUrl/bot$token/sendMessage');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': text,
          'parse_mode': 'MarkdownV2',
        }),
      );

      if (response.statusCode == 200) {
        String? messageId;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final result = body['result'] as Map<String, dynamic>?;
          final id = result?['message_id'];
          if (id != null) messageId = id.toString();
        } catch (_) {}
        return TelegramSendResult(success: true, messageId: messageId);
      } else {
        String? msg;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          msg = body['description'] as String?;
        } catch (_) {}
        return TelegramSendResult(
          success: false,
          errorMessage: msg ?? 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return TelegramSendResult(success: false, errorMessage: e.toString());
    }
  }

  /// Edits an already-sent message identified by [messageId].
  /// Returns true on success.
  Future<bool> editMessage(
    TelegramConnection connection,
    String messageId,
    String text,
  ) async {
    final token = connection.botToken.trim();
    final chatId = connection.chatId.trim();
    if (token.isEmpty || chatId.isEmpty) return false;

    final uri = Uri.parse('$_baseUrl/bot$token/editMessageText');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'message_id': int.tryParse(messageId) ?? messageId,
          'text': text,
          'parse_mode': 'MarkdownV2',
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
