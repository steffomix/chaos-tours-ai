import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/matrix_connection.dart';
import 'settings_service.dart';

class MatrixSendResult {
  final bool success;
  final String? errorMessage;

  /// The Matrix event_id when a message was sent successfully.
  final String? eventId;

  const MatrixSendResult({
    required this.success,
    this.errorMessage,
    this.eventId,
  });
}

class MatrixMembershipResult {
  final bool isMember;
  final String? errorMessage;

  const MatrixMembershipResult({required this.isMember, this.errorMessage});
}

/// Sends messages via the Matrix Client-Server API.
class MatrixService {
  MatrixService._();
  static final MatrixService instance = MatrixService._();

  String _normalizeHomeserver(String homeserver) {
    var s = homeserver.trim();
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  /// Sends a plain-text [text] message to the room defined by [connection].
  Future<MatrixSendResult> sendMessage(
    MatrixConnection connection,
    String text,
  ) async {
    final token =
        (SettingsService.instance.getMatrixAccessToken(connection.uuid) ?? '')
            .trim();
    final homeserver = _normalizeHomeserver(connection.homeserver);
    final roomId = connection.roomId.trim();

    if (token.isEmpty || homeserver.isEmpty || roomId.isEmpty) {
      return const MatrixSendResult(
        success: false,
        errorMessage: 'Access-Token, Homeserver oder Raum-ID fehlt',
      );
    }

    final txnId = DateTime.now().millisecondsSinceEpoch.toString();
    final encodedRoomId = Uri.encodeComponent(roomId);
    final uri = Uri.parse(
      '$homeserver/_matrix/client/v3/rooms/$encodedRoomId/send/m.room.message/$txnId',
    );

    try {
      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'msgtype': 'm.text', 'body': text}),
      );

      if (response.statusCode == 200) {
        String? eventId;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          eventId = body['event_id'] as String?;
        } catch (_) {}
        return MatrixSendResult(success: true, eventId: eventId);
      } else {
        String? msg;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          msg = body['error'] as String?;
        } catch (_) {}
        return MatrixSendResult(
          success: false,
          errorMessage: msg ?? 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return MatrixSendResult(success: false, errorMessage: e.toString());
    }
  }

  /// Edits a previously sent message (identified by [originalEventId]).
  Future<MatrixSendResult> editMessage(
    MatrixConnection connection,
    String originalEventId,
    String newText,
  ) async {
    final token =
        (SettingsService.instance.getMatrixAccessToken(connection.uuid) ?? '')
            .trim();
    final homeserver = _normalizeHomeserver(connection.homeserver);
    final roomId = connection.roomId.trim();

    if (token.isEmpty || homeserver.isEmpty || roomId.isEmpty) {
      return const MatrixSendResult(
        success: false,
        errorMessage: 'Access-Token, Homeserver oder Raum-ID fehlt',
      );
    }

    final txnId =
        '${DateTime.now().millisecondsSinceEpoch}_edit_$originalEventId';
    final encodedRoomId = Uri.encodeComponent(roomId);
    final uri = Uri.parse(
      '$homeserver/_matrix/client/v3/rooms/$encodedRoomId/send/m.room.message/$txnId',
    );

    try {
      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'msgtype': 'm.text',
          'body': '* $newText',
          'm.new_content': {'msgtype': 'm.text', 'body': newText},
          'm.relates_to': {
            'rel_type': 'm.replace',
            'event_id': originalEventId,
          },
        }),
      );

      if (response.statusCode == 200) {
        String? eventId;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          eventId = body['event_id'] as String?;
        } catch (_) {}
        return MatrixSendResult(success: true, eventId: eventId);
      } else {
        String? msg;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          msg = body['error'] as String?;
        } catch (_) {}
        return MatrixSendResult(
          success: false,
          errorMessage: msg ?? 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return MatrixSendResult(success: false, errorMessage: e.toString());
    }
  }

  /// Checks whether the account belonging to [connection]'s access token
  /// is a member of the configured room.
  Future<MatrixMembershipResult> checkRoomMembership(
    MatrixConnection connection,
  ) async {
    final token =
        (SettingsService.instance.getMatrixAccessToken(connection.uuid) ?? '')
            .trim();
    final homeserver = _normalizeHomeserver(connection.homeserver);
    final roomId = connection.roomId.trim();

    if (token.isEmpty || homeserver.isEmpty || roomId.isEmpty) {
      return const MatrixMembershipResult(
        isMember: false,
        errorMessage: 'Access-Token, Homeserver oder Raum-ID fehlt',
      );
    }

    final uri = Uri.parse('$homeserver/_matrix/client/v3/joined_rooms');

    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rooms =
            (body['joined_rooms'] as List<dynamic>?)?.cast<String>() ?? [];
        final isMember = rooms.contains(roomId);
        return MatrixMembershipResult(isMember: isMember);
      } else {
        String? msg;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          msg = body['error'] as String?;
        } catch (_) {}
        return MatrixMembershipResult(
          isMember: false,
          errorMessage: msg ?? 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return MatrixMembershipResult(
        isMember: false,
        errorMessage: e.toString(),
      );
    }
  }
}
