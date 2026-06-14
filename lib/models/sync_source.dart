import 'dart:convert';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Sync options for a single table (insert/update/delete independently).
class SyncTableOptions {
  final bool insert;
  final bool update;
  final bool delete;

  const SyncTableOptions({
    this.insert = false,
    this.update = false,
    this.delete = false,
  });

  factory SyncTableOptions.fromMap(Map<String, dynamic> m) => SyncTableOptions(
    insert: (m['insert'] as bool?) ?? false,
    update: (m['update'] as bool?) ?? false,
    delete: (m['delete'] as bool?) ?? false,
  );

  Map<String, dynamic> toMap() => {
    'insert': insert,
    'update': update,
    'delete': delete,
  };

  SyncTableOptions copyWith({bool? insert, bool? update, bool? delete}) =>
      SyncTableOptions(
        insert: insert ?? this.insert,
        update: update ?? this.update,
        delete: delete ?? this.delete,
      );

  bool get anyEnabled => insert || update || delete;
}

/// All per-table sync options for a [SyncSource].
/// Default: only saved_places.insert is enabled.
class SyncSourceOptions {
  static const allTables = [
    'place_groups',
    'saved_places',
    'persons',
    'activities',
    'stays',
    'stay_persons',
    'stay_activities',
    'aktivitaeten',
    'sync_sources',
    'place_experiences',
    'sync_source_experiences',
    'place_photos',
  ];

  final Map<String, SyncTableOptions> tables;

  SyncSourceOptions({Map<String, SyncTableOptions>? tables})
    : tables = tables ?? _defaults();

  static Map<String, SyncTableOptions> _defaults() => {
    for (final t in allTables)
      t: t == 'saved_places'
          ? const SyncTableOptions(insert: true)
          : const SyncTableOptions(),
  };

  factory SyncSourceOptions.fromJson(String json) {
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      final tableMap = <String, SyncTableOptions>{};
      for (final t in allTables) {
        final raw = m[t];
        if (raw is Map<String, dynamic>) {
          tableMap[t] = SyncTableOptions.fromMap(raw);
        } else {
          tableMap[t] = const SyncTableOptions();
        }
      }
      return SyncSourceOptions(tables: tableMap);
    } catch (_) {
      return SyncSourceOptions();
    }
  }

  String toJson() => jsonEncode(tables.map((k, v) => MapEntry(k, v.toMap())));

  SyncSourceOptions copyWithTable(String table, SyncTableOptions opts) {
    final updated = Map<String, SyncTableOptions>.from(tables);
    updated[table] = opts;
    return SyncSourceOptions(tables: updated);
  }

  SyncTableOptions forTable(String table) =>
      tables[table] ?? const SyncTableOptions();
}

/// A remote server used for bidirectional data sync.
/// Also optionally provides a public info URL for additional information.
class SyncSource {
  final String uuid;

  /// Display name for this source.
  final String name;

  /// Base URL of the sync server (e.g. http://192.168.1.10:8000).
  final String syncUrl;

  /// API key for authenticating against the sync server.
  final String apiKey;

  /// Optional public URL providing additional information about this source.
  final String infoUrl;

  /// Description / notes about this source.
  final String description;

  /// Per-table sync options.
  final SyncSourceOptions syncOptions;

  // ── Sync fields ──────────────────────────────────────────────────────────
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  SyncSource({
    String? uuid,
    required this.name,
    required this.syncUrl,
    this.apiKey = '',
    this.infoUrl = '',
    this.description = '',
    SyncSourceOptions? syncOptions,
    int? updatedAt,
    this.deletedAt,
    this.deviceId = '',
  }) : syncOptions = syncOptions ?? SyncSourceOptions(),
       uuid = uuid?.isNotEmpty == true ? uuid! : _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  factory SyncSource.fromMap(Map<String, dynamic> map) {
    SyncSourceOptions opts;
    final raw = map['sync_options'] as String?;
    if (raw != null && raw.isNotEmpty) {
      opts = SyncSourceOptions.fromJson(raw);
    } else {
      opts = SyncSourceOptions();
    }
    return SyncSource(
      uuid: map['uuid'] as String?,
      name: map['name'] as String,
      syncUrl: (map['sync_url'] as String?) ?? '',
      apiKey: (map['api_key'] as String?) ?? '',
      infoUrl: (map['info_url'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      syncOptions: opts,
      updatedAt:
          (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      deletedAt: map['deleted_at'] as int?,
      deviceId: (map['device_id'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'name': name,
      'sync_url': syncUrl,
      'api_key': apiKey,
      'info_url': infoUrl,
      'description': description,
      'sync_options': syncOptions.toJson(),
      'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      'device_id': deviceId,
    };
  }

  SyncSource copyWith({
    String? uuid,
    String? name,
    String? syncUrl,
    String? apiKey,
    String? infoUrl,
    String? description,
    SyncSourceOptions? syncOptions,
    int? updatedAt,
    int? deletedAt,
    String? deviceId,
  }) {
    return SyncSource(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      syncUrl: syncUrl ?? this.syncUrl,
      apiKey: apiKey ?? this.apiKey,
      infoUrl: infoUrl ?? this.infoUrl,
      description: description ?? this.description,
      syncOptions: syncOptions ?? this.syncOptions,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
