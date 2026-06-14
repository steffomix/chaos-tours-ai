import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/telegram_connection.dart';

class TelegramSendResult {
  final bool success;
  final String? errorMessage;

  const TelegramSendResult({required this.success, this.errorMessage});
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
        return const TelegramSendResult(success: true);
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
}
