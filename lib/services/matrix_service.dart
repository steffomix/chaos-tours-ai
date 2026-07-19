import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/matrix_connection.dart';
import 'settings_service.dart';

class MatrixSendResult {
  final bool success;
  final String? errorMessage;

  /// The Matrix event_id when a message was sent successfully.
  final String? eventId;

  /// True when the server responded with HTTP 401 (expired / invalid token).
  final bool isAuthError;

  const MatrixSendResult({
    required this.success,
    this.errorMessage,
    this.eventId,
    this.isAuthError = false,
  });
}

class MatrixMembershipResult {
  final bool isMember;
  final String? errorMessage;

  const MatrixMembershipResult({required this.isMember, this.errorMessage});
}

class MatrixLoginResult {
  final bool success;
  final String? errorMessage;

  /// The new access token returned on successful login.
  final String? accessToken;

  const MatrixLoginResult({
    required this.success,
    this.errorMessage,
    this.accessToken,
  });
}

/// Sends messages via the Matrix Client-Server API.
class MatrixService {
  MatrixService._();
  static final MatrixService instance = MatrixService._();

  String _normalizeHomeserver(String homeserver) {
    var s = homeserver.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Returns the token to use: [overrideToken] (from UI testing) takes
  /// precedence over the token stored in SharedPreferences.
  String _resolveToken(String connectionUuid, String? overrideToken) {
    if (overrideToken != null && overrideToken.trim().isNotEmpty) {
      return overrideToken.trim();
    }
    return (SettingsService.instance.getMatrixAccessToken(connectionUuid) ?? '')
        .trim();
  }

  // ── Login ────────────────────────────────────────────────────────────────

  /// Logs in with [username] and [password] on [homeserver].
  /// On success the new access token (and refresh token if supported) are
  /// stored automatically for [connectionUuid].
  Future<MatrixLoginResult> login(
    String connectionUuid,
    String homeserver,
    String username,
    String password,
  ) async {
    final hs = _normalizeHomeserver(homeserver);
    final uri = Uri.parse('$hs/_matrix/client/v3/login');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'm.login.password',
          'identifier': {'type': 'm.id.user', 'user': username},
          'password': password,
          'refresh_token': true,
        }),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final accessToken = body['access_token'] as String?;
        final refreshToken = body['refresh_token'] as String?;
        if (accessToken == null) {
          return const MatrixLoginResult(
            success: false,
            errorMessage: 'Kein Access-Token in der Antwort erhalten',
          );
        }
        await SettingsService.instance.setMatrixAccessToken(
          connectionUuid,
          accessToken,
        );
        if (refreshToken != null) {
          await SettingsService.instance.setMatrixRefreshToken(
            connectionUuid,
            refreshToken,
          );
        }
        return MatrixLoginResult(success: true, accessToken: accessToken);
      } else {
        String? msg;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          msg = body['error'] as String?;
        } catch (_) {}
        return MatrixLoginResult(
          success: false,
          errorMessage: msg ?? 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return MatrixLoginResult(success: false, errorMessage: e.toString());
    }
  }

  // ── Token refresh ─────────────────────────────────────────────────────────

  /// Tries to obtain a fresh access token:
  /// 1. Uses the stored refresh token (Matrix spec >= 1.3).
  /// 2. Falls back to re-login with stored credentials.
  Future<bool> _tryRefreshOrRelogin(MatrixConnection connection) async {
    final hs = _normalizeHomeserver(connection.homeserver);

    // 1. Refresh token
    final refreshToken = SettingsService.instance.getMatrixRefreshToken(
      connection.uuid,
    );
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        final uri = Uri.parse('$hs/_matrix/client/v3/refresh');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        );
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final newAccess = body['access_token'] as String?;
          final newRefresh = body['refresh_token'] as String?;
          if (newAccess != null) {
            await SettingsService.instance.setMatrixAccessToken(
              connection.uuid,
              newAccess,
            );
            if (newRefresh != null) {
              await SettingsService.instance.setMatrixRefreshToken(
                connection.uuid,
                newRefresh,
              );
            }
            return true;
          }
        }
      } catch (_) {}
    }

    // 2. Re-login with stored credentials
    final creds = SettingsService.instance.getMatrixCredentials(
      connection.uuid,
    );
    if (creds != null) {
      final result = await login(
        connection.uuid,
        connection.homeserver,
        creds['username'] ?? '',
        creds['password'] ?? '',
      );
      return result.success;
    }

    return false;
  }

  // ── Send message ──────────────────────────────────────────────────────────

  /// Sends a plain-text [text] message to the room defined by [connection].
  ///
  /// Pass [overrideToken] to test before saving credentials (auto-refresh is
  /// skipped when an override token is given).
  Future<MatrixSendResult> sendMessage(
    MatrixConnection connection,
    String text, {
    String? overrideToken,
  }) async {
    var result = await _doSendMessage(
      connection,
      text,
      overrideToken: overrideToken,
    );
    if (result.isAuthError && overrideToken == null) {
      final refreshed = await _tryRefreshOrRelogin(connection);
      if (refreshed) {
        result = await _doSendMessage(connection, text);
      }
    }
    return result;
  }

  Future<MatrixSendResult> _doSendMessage(
    MatrixConnection connection,
    String text, {
    String? overrideToken,
  }) async {
    final token = _resolveToken(connection.uuid, overrideToken);
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
        final isAuth = response.statusCode == 401;
        String? msg;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          msg = body['error'] as String?;
        } catch (_) {}
        return MatrixSendResult(
          success: false,
          errorMessage: msg ?? 'HTTP ${response.statusCode}',
          isAuthError: isAuth,
        );
      }
    } catch (e) {
      return MatrixSendResult(success: false, errorMessage: e.toString());
    }
  }

  // ── Edit message ──────────────────────────────────────────────────────────

  /// Edits a previously sent message via the m.replace relation.
  /// Automatically tries to refresh the token on 401.
  Future<MatrixSendResult> editMessage(
    MatrixConnection connection,
    String originalEventId,
    String newText,
  ) async {
    var result = await _doEditMessage(connection, originalEventId, newText);
    if (result.isAuthError) {
      final refreshed = await _tryRefreshOrRelogin(connection);
      if (refreshed) {
        result = await _doEditMessage(connection, originalEventId, newText);
      }
    }
    return result;
  }

  Future<MatrixSendResult> _doEditMessage(
    MatrixConnection connection,
    String originalEventId,
    String newText,
  ) async {
    final token = _resolveToken(connection.uuid, null);
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
        final isAuth = response.statusCode == 401;
        String? msg;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          msg = body['error'] as String?;
        } catch (_) {}
        return MatrixSendResult(
          success: false,
          errorMessage: msg ?? 'HTTP ${response.statusCode}',
          isAuthError: isAuth,
        );
      }
    } catch (e) {
      return MatrixSendResult(success: false, errorMessage: e.toString());
    }
  }

  // ── Room membership ───────────────────────────────────────────────────────

  /// Checks whether the account is a joined member of [connection]'s room.
  /// Pass [overrideToken] to test without saving credentials first.
  Future<MatrixMembershipResult> checkRoomMembership(
    MatrixConnection connection, {
    String? overrideToken,
  }) async {
    final token = _resolveToken(connection.uuid, overrideToken);
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

  // ── Joined rooms list ─────────────────────────────────────────────────────

  /// Loads all rooms the account has joined, enriched with room name and
  /// canonical alias fetched in parallel. Returns (rooms, errorMessage).
  Future<(List<MatrixRoomInfo>, String?)> loadJoinedRooms(
    MatrixConnection connection, {
    String? overrideToken,
  }) async {
    final token = _resolveToken(connection.uuid, overrideToken);
    final homeserver = _normalizeHomeserver(connection.homeserver);

    if (token.isEmpty || homeserver.isEmpty) {
      return (<MatrixRoomInfo>[], 'Access-Token oder Homeserver fehlt');
    }

    final listUri = Uri.parse('$homeserver/_matrix/client/v3/joined_rooms');
    try {
      final listResp = await http.get(
        listUri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (listResp.statusCode != 200) {
        String? msg;
        try {
          msg =
              (jsonDecode(listResp.body) as Map<String, dynamic>)['error']
                  as String?;
        } catch (_) {}
        return (<MatrixRoomInfo>[], msg ?? 'HTTP ${listResp.statusCode}');
      }

      final roomIds =
          ((jsonDecode(listResp.body) as Map<String, dynamic>)['joined_rooms']
                  as List<dynamic>?)
              ?.cast<String>() ??
          [];

      // Fetch name + canonical alias for each room in parallel.
      final headers = {'Authorization': 'Bearer $token'};
      final infos = await Future.wait(
        roomIds.map((roomId) async {
          final enc = Uri.encodeComponent(roomId);
          String? name;
          String? alias;

          await Future.wait([
            http
                .get(
                  Uri.parse(
                    '$homeserver/_matrix/client/v3/rooms/$enc/state/m.room.name',
                  ),
                  headers: headers,
                )
                .then((r) {
                  if (r.statusCode == 200) {
                    name =
                        (jsonDecode(r.body) as Map<String, dynamic>)['name']
                            as String?;
                  }
                })
                .catchError((_) {}),
            http
                .get(
                  Uri.parse(
                    '$homeserver/_matrix/client/v3/rooms/$enc/state/m.room.canonical_alias',
                  ),
                  headers: headers,
                )
                .then((r) {
                  if (r.statusCode == 200) {
                    alias =
                        (jsonDecode(r.body) as Map<String, dynamic>)['alias']
                            as String?;
                  }
                })
                .catchError((_) {}),
          ]);

          return MatrixRoomInfo(roomId: roomId, name: name, alias: alias);
        }),
      );

      infos.sort((a, b) => a.displayName.compareTo(b.displayName));
      return (infos, null);
    } catch (e) {
      return (<MatrixRoomInfo>[], e.toString());
    }
  }
}

// ── MatrixRoomInfo ────────────────────────────────────────────────────────────

class MatrixRoomInfo {
  final String roomId;
  final String? name;
  final String? alias;

  const MatrixRoomInfo({required this.roomId, this.name, this.alias});

  /// Best human-readable label (name > alias > roomId).
  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (alias != null && alias!.isNotEmpty) return alias!;
    return roomId;
  }

  /// Secondary line shown in the picker (alias or roomId when name is set).
  String? get displaySubtitle {
    if (name != null && name!.isNotEmpty) return alias ?? roomId;
    if (alias != null && alias!.isNotEmpty) return roomId;
    return null;
  }
}
