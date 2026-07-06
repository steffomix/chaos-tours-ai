import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sync_source.dart';
import 'database_service.dart';
import 'settings_service.dart';

/// Legacy single-table sync options (used by [DatabaseService.upsertByUuid]).
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

/// Result of a sync operation against a single server.
class SyncResult {
  final bool success;
  final String? errorMessage;
  final int pulled;
  final int pushed;
  final String sourceName;

  const SyncResult({
    required this.success,
    this.errorMessage,
    this.pulled = 0,
    this.pushed = 0,
    this.sourceName = '',
  });
}

/// Service for synchronising the local SQLite database with one or more
/// remote FastAPI sync servers (PostgreSQL).
///
/// Each [SyncSource] has its own URL, API key, and per-table [SyncSourceOptions].
/// Sync strategy: timestamp-based delta, last-write-wins per [updated_at].
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// Returns the persistent device ID from [SettingsService].
  String get deviceId => SettingsService.instance.deviceId;

  // ── Main sync entry points ─────────────────────────────────────────────────

  /// Syncs with all configured (non-deleted) sync sources.
  /// Returns one [SyncResult] per source that has any sync option enabled.
  Future<List<SyncResult>> syncAll() async {
    final sources = await DatabaseService.instance.loadAllSyncSources();
    final results = <SyncResult>[];

    for (final source in sources) {
      if (source.syncUrl.isEmpty) continue;
      final anyEnabled = source.syncOptions.tables.values.any(
        (opts) => opts.anyEnabled,
      );
      if (!anyEnabled) continue;

      final result = await _syncWithSource(source);
      results.add(result);
    }

    if (results.isNotEmpty) {
      await DatabaseService.instance.refreshTrustedSources();
    }
    return results;
  }

  /// Syncs with a single [SyncSource].
  Future<SyncResult> syncWithSource(SyncSource source) async {
    final result = await _syncWithSource(source);
    await DatabaseService.instance.refreshTrustedSources();
    return result;
  }

  /// Opportunistic mesh sync against a freshly discovered node reachable at
  /// [baseUrl] (e.g. `http://192.168.4.1:8000`). Uses full insert+update table
  /// options so all shared data (messages, attachments, photos, places…) is
  /// exchanged epidemically. Does not persist the node as a [SyncSource].
  /// Always performs a full sync (since=0) because the node is ephemeral.
  Future<SyncResult> syncWithNode(String baseUrl, {String apiKey = ''}) async {
    final ephemeral = SyncSource(
      name: baseUrl,
      syncUrl: baseUrl,
      apiKey: apiKey,
      syncOptions: SyncSourceOptions.allEnabled(),
    );
    final result = await _syncWithSource(ephemeral);
    await DatabaseService.instance.refreshTrustedSources();
    return result;
  }

  // ── Internal sync logic ───────────────────────────────────────────────────

  Future<SyncResult> _syncWithSource(SyncSource source) async {
    try {
      final devId = deviceId;
      final since = source.lastSyncMs;

      // Determine which tables participate (any option enabled).
      final activeTables = SyncSourceOptions.allTables
          .where((t) => source.syncOptions.forTable(t).anyEnabled)
          .toList();

      if (activeTables.isEmpty) {
        return SyncResult(success: true, sourceName: source.name);
      }

      // Load private-space protection sets once per sync.
      final importProtected = await DatabaseService.instance
          .loadImportProtectedDeviceIds();
      final exportProtected = await DatabaseService.instance
          .loadExportProtectedDeviceIds();

      // ── 1. Pull changes from server ─────────────────────────────────────
      final pullUri = Uri.parse(
        '${source.syncUrl}/sync/pull?since=$since&device_id=$deviceId',
      );
      final pullResp = await http
          .get(pullUri, headers: _headers(source.apiKey))
          .timeout(const Duration(seconds: 30));

      if (pullResp.statusCode != 200) {
        return SyncResult(
          success: false,
          errorMessage: 'Pull fehlgeschlagen: ${pullResp.statusCode}',
          sourceName: source.name,
        );
      }

      final pullData = jsonDecode(pullResp.body) as Map<String, dynamic>;
      int pulled = 0;
      for (final table in activeTables) {
        final tableOpts = source.syncOptions.forTable(table);
        final rows = pullData[table] as List<dynamic>? ?? [];
        for (final row in rows) {
          final rowMap = Map<String, dynamic>.from(row as Map);
          // Skip rows whose device_id belongs to an import-protected Aktivitaet.
          final rowDeviceId = rowMap['device_id'] as String?;
          if (rowDeviceId != null && importProtected.contains(rowDeviceId)) {
            continue;
          }
          await DatabaseService.instance.upsertByUuid(
            table,
            rowMap,
            options: SyncOptions(
              allowInsert: tableOpts.insert,
              allowEdit: tableOpts.update,
              allowDelete: tableOpts.delete,
            ),
          );
          pulled++;
        }
      }

      // ── 2. Push local changes to server ─────────────────────────────────
      final pushPayload = <String, dynamic>{};
      for (final table in activeTables) {
        final rows = await DatabaseService.instance.loadChangedRows(
          table,
          since,
        );
        // Filter out rows whose device_id belongs to an export-protected Aktivitaet.
        final filtered = exportProtected.isEmpty
            ? rows
            : rows
                  .where(
                    (r) => !exportProtected.contains(r['device_id'] as String?),
                  )
                  .toList();
        if (filtered.isNotEmpty) {
          pushPayload[table] = filtered;
        }
      }

      int pushed = 0;
      if (pushPayload.isNotEmpty) {
        final pushUri = Uri.parse('${source.syncUrl}/sync/push');
        final pushResp = await http
            .post(
              pushUri,
              headers: {
                ..._headers(source.apiKey),
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'device_id': devId, 'data': pushPayload}),
            )
            .timeout(const Duration(seconds: 30));

        if (pushResp.statusCode != 200) {
          return SyncResult(
            success: false,
            errorMessage: 'Push fehlgeschlagen: ${pushResp.statusCode}',
            sourceName: source.name,
          );
        }

        for (final rows in pushPayload.values) {
          pushed += (rows as List).length;
        }
      }

      // Persist the per-source sync timestamp (device-local, not synced).
      if (source.uuid.isNotEmpty) {
        await DatabaseService.instance.updateSyncSourceLastSyncMs(
          source.uuid,
          DateTime.now().millisecondsSinceEpoch,
        );
      }

      return SyncResult(
        success: true,
        pulled: pulled,
        pushed: pushed,
        sourceName: source.name,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        errorMessage: e.toString(),
        sourceName: source.name,
      );
    }
  }

  Map<String, String> _headers(String key) {
    if (key.isEmpty) return {};
    return {'X-Api-Key': key};
  }
}
