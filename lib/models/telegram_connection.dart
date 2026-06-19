import 'package:uuid/uuid.dart';

import '../services/settings_service.dart';

const _uuid = Uuid();

/// A Telegram bot connection used to send place reports to a chat or channel.
class TelegramConnection {
  final String uuid;

  /// Display name for this connection.
  final String name;

  /// Optional description / notes.
  final String description;

  /// Telegram chat ID (numeric, e.g. "-1001234567890") or channel username
  /// (e.g. "@mychannel").
  final String chatId;

  /// Bot token (e.g. "123456:ABC-DEF…").
  final String botToken;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  TelegramConnection({
    String? uuid,
    required this.name,
    this.description = '',
    required this.chatId,
    required this.botToken,
    int? updatedAt,
    this.deletedAt,
    String? deviceId,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch,
       deviceId = deviceId?.isNotEmpty == true
           ? deviceId!
           : SettingsService.instance.deviceId;

  factory TelegramConnection.fromMap(Map<String, dynamic> map) {
    return TelegramConnection(
      uuid: map['uuid'] as String?,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      chatId: (map['chat_id'] as String?) ?? '',
      botToken: (map['bot_token'] as String?) ?? '',
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
      deviceId:
          (map['device_id'] as String?) ?? SettingsService.instance.deviceId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'name': name,
      'description': description,
      'chat_id': chatId,
      'bot_token': botToken,
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  TelegramConnection copyWith({
    String? uuid,
    String? name,
    String? description,
    String? chatId,
    String? botToken,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    String? deviceId,
  }) {
    return TelegramConnection(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      description: description ?? this.description,
      chatId: chatId ?? this.chatId,
      botToken: botToken ?? this.botToken,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deviceId: deviceId ?? this.deviceId,
    );
  }

  /// Returns a clickable Telegram URL for [chatId].
  /// Numeric IDs cannot be opened directly via URL, so we show the raw ID for
  /// those; usernames become https://t.me/username.
  String? get telegramUrl {
    final id = chatId.trim();
    if (id.isEmpty) return null;
    if (id.startsWith('@')) {
      return 'https://t.me/${id.substring(1)}';
    }
    // Numeric chat ID – no universally openable deep-link
    return null;
  }

  @override
  String toString() => 'TelegramConnection($uuid, $name)';
}
