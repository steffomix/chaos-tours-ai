import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_place.dart';
import '../models/web_source.dart';
import 'database_service.dart';

/// Options controlling which pull operations are applied to local data.
class SyncOptions {
  /// Allow inserting records that exist on the server but not locally.
  final bool allowInsert;

  /// Allow updating records where the server version is newer.
  final bool allowEdit;

  /// Allow soft-deleting local records that the server has marked deleted.
  final bool allowDelete;

  const SyncOptions({
    this.allowInsert = true,
    this.allowEdit = true,
    this.allowDelete = true,
  });

  static const all = SyncOptions();
}

/// Result of a sync operation.
class SyncResult {
  final bool success;
  final String? errorMessage;
  final int pulled;
  final int pushed;

  const SyncResult({
    required this.success,
    this.errorMessage,
    this.pulled = 0,
    this.pushed = 0,
  });
}

/// Service for synchronising the local SQLite database with a remote
/// FastAPI server (PostgreSQL).
///
/// Sync strategy: timestamp-based delta, last-write-wins per [updated_at].
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _keySyncServerUrl = 'sync_server_url';
  static const _keySyncApiKey = 'sync_api_key';
  static const _keyLastSyncMs = 'sync_last_ms';
  static const _keyDeviceId = 'sync_device_id';

  // Tables that participate in sync (order matters for foreign keys).
  static const _syncTables = [
    'place_groups',
    'saved_places',
    'persons',
    'activities',
    'stays',
    'stay_persons',
    'stay_activities',
    'aktivitaeten',
    'web_sources',
    'web_source_experiences',
  ];

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Settings accessors ────────────────────────────────────────────────────

  Future<String> get serverUrl async =>
      (await _p).getString(_keySyncServerUrl) ?? '';
  Future<void> setServerUrl(String v) async =>
      (await _p).setString(_keySyncServerUrl, v);

  Future<String> get apiKey async =>
      (await _p).getString(_keySyncApiKey) ?? 'chaos-tours-2-promised-land';
  Future<void> setApiKey(String v) async =>
      (await _p).setString(_keySyncApiKey, v);

  Future<int> get lastSyncMs async => (await _p).getInt(_keyLastSyncMs) ?? 0;
  Future<void> _setLastSyncMs(int ms) async =>
      (await _p).setInt(_keyLastSyncMs, ms);

  /// Returns the persistent device ID, creating one on first call.
  Future<String> get deviceId async {
    final p = await _p;
    var id = p.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      id = DatabaseService.generateUuid();
      await p.setString(_keyDeviceId, id);
    }
    return id;
  }

  // ── Main sync entry points ─────────────────────────────────────────────────

  /// Full delta-sync with the configured server URL.
  Future<SyncResult> syncWithServer({
    SyncOptions options = SyncOptions.all,
  }) async {
    final url = await serverUrl;
    final key = await apiKey;
    if (url.isEmpty) {
      return const SyncResult(
        success: false,
        errorMessage: 'Keine Server-URL konfiguriert',
      );
    }
    return _sync(url, key, options: options);
  }

  /// Imports only [SavedPlace] records from a [WebSource].
  /// Imported places receive [PlaceOriginType.imported] and the source UUID.
  Future<SyncResult> importFromWebSource(WebSource source) async {
    try {
      final uri = Uri.parse('${source.url}/places/export');
      final resp = await http
          .get(uri, headers: _headers(source.apiKey))
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        return SyncResult(
          success: false,
          errorMessage: 'Server antwortete mit ${resp.statusCode}',
        );
      }

      final List<dynamic> raw = jsonDecode(resp.body) as List<dynamic>;
      int imported = 0;
      final devId = await deviceId;

      for (final item in raw) {
        final map = Map<String, dynamic>.from(item as Map);
        // Mark as imported and reference the source.
        map['origin_type'] = PlaceOriginType.imported.index;
        map['origin_source_uuid'] = source.uuid;
        // Strip remote integer id — upsertByUuid will handle conflicts.
        map.remove('id');
        if ((map['uuid'] as String?)?.isEmpty ?? true) {
          map['uuid'] = DatabaseService.generateUuid();
        }
        map['device_id'] = devId;
        await DatabaseService.instance.upsertByUuid('saved_places', map);
        imported++;
      }

      return SyncResult(success: true, pulled: imported);
    } catch (e) {
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }

  // ── Internal sync logic ───────────────────────────────────────────────────

  Future<SyncResult> _sync(
    String baseUrl,
    String key, {
    SyncOptions options = SyncOptions.all,
  }) async {
    try {
      final devId = await deviceId;
      final since = await lastSyncMs;
      final now = DateTime.now().millisecondsSinceEpoch;

      // ── 1. Pull changes from server ─────────────────────────────────────
      final pullUri = Uri.parse(
        '$baseUrl/sync/pull?since=$since&device_id=$devId',
      );
      final pullResp = await http
          .get(pullUri, headers: _headers(key))
          .timeout(const Duration(seconds: 30));

      if (pullResp.statusCode != 200) {
        return SyncResult(
          success: false,
          errorMessage: 'Pull fehlgeschlagen: ${pullResp.statusCode}',
        );
      }

      final pullData = jsonDecode(pullResp.body) as Map<String, dynamic>;
      int pulled = 0;
      for (final table in _syncTables) {
        final rows = pullData[table] as List<dynamic>? ?? [];
        for (final row in rows) {
          await DatabaseService.instance.upsertByUuid(
            table,
            Map<String, dynamic>.from(row as Map),
            options: options,
          );
          pulled++;
        }
      }

      // ── 2. Push local changes to server ─────────────────────────────────
      final pushPayload = <String, dynamic>{};
      for (final table in _syncTables) {
        final rows = await DatabaseService.instance.loadChangedRows(
          table,
          since,
        );
        if (rows.isNotEmpty) {
          pushPayload[table] = rows;
        }
      }

      int pushed = 0;
      if (pushPayload.isNotEmpty) {
        final pushUri = Uri.parse('$baseUrl/sync/push');
        final pushResp = await http
            .post(
              pushUri,
              headers: {..._headers(key), 'Content-Type': 'application/json'},
              body: jsonEncode({'device_id': devId, 'data': pushPayload}),
            )
            .timeout(const Duration(seconds: 30));

        if (pushResp.statusCode != 200) {
          return SyncResult(
            success: false,
            errorMessage: 'Push fehlgeschlagen: ${pushResp.statusCode}',
          );
        }

        for (final rows in pushPayload.values) {
          pushed += (rows as List).length;
        }
      }

      await _setLastSyncMs(now);
      return SyncResult(success: true, pulled: pulled, pushed: pushed);
    } catch (e) {
      return SyncResult(success: false, errorMessage: e.toString());
    }
  }

  Map<String, String> _headers(String key) {
    if (key.isEmpty) return {};
    return {'X-Api-Key': key};
  }
}
