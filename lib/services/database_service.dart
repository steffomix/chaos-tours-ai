import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/aktivitaet.dart';
import '../models/activity.dart';
import '../models/web_source_experience.dart';
import '../models/person.dart';
import '../models/place_group.dart';
import '../models/saved_place.dart';
import '../models/stay.dart';
import '../models/stay_activity.dart';
import '../models/stay_person.dart';
import '../models/tracking_point.dart';
import '../models/web_source.dart';
import 'sync_service.dart' show SyncOptions;

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _uuid = Uuid();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _openDatabase();
    return _db!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'chaos_tours.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  // ── Schema helpers ───────────────────────────────────────────────────────

  /// Adds the four sync columns to [table] if they are not yet present.
  Future<void> _addSyncColumns(DatabaseExecutor db, String table) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final existing = cols.map((c) => c['name'] as String).toSet();
    if (!existing.contains('uuid')) {
      await db.execute(
        "ALTER TABLE $table ADD COLUMN uuid TEXT NOT NULL DEFAULT ''",
      );
    }
    if (!existing.contains('updated_at')) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!existing.contains('deleted_at')) {
      await db.execute('ALTER TABLE $table ADD COLUMN deleted_at INTEGER');
    }
    if (!existing.contains('device_id')) {
      await db.execute(
        "ALTER TABLE $table ADD COLUMN device_id TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync columns to all existing tables.
      for (final table in [
        'saved_places',
        'place_groups',
        'stays',
        'persons',
        'activities',
        'stay_persons',
        'stay_activities',
        'aktivitaeten',
      ]) {
        await _addSyncColumns(db, table);
      }

      // Add origin columns to saved_places.
      final cols = await db.rawQuery('PRAGMA table_info(saved_places)');
      final existing = cols.map((c) => c['name'] as String).toSet();
      if (!existing.contains('origin_type')) {
        await db.execute(
          'ALTER TABLE saved_places ADD COLUMN origin_type INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!existing.contains('origin_source_uuid')) {
        await db.execute(
          'ALTER TABLE saved_places ADD COLUMN origin_source_uuid TEXT',
        );
      }

      // Create new web_sources table.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS web_sources (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          notes TEXT NOT NULL DEFAULT '',
          experience TEXT NOT NULL DEFAULT '',
          api_key TEXT NOT NULL DEFAULT '',
          uuid TEXT NOT NULL DEFAULT '',
          updated_at INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          device_id TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
    if (oldVersion < 3) {
      // Create web_source_experiences table.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS web_source_experiences (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          web_source_uuid TEXT NOT NULL,
          text TEXT NOT NULL,
          created_at INTEGER NOT NULL DEFAULT 0,
          uuid TEXT NOT NULL DEFAULT '',
          updated_at INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          device_id TEXT NOT NULL DEFAULT ''
        )
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE saved_places (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        radius REAL NOT NULL DEFAULT 50.0,
        notes TEXT NOT NULL DEFAULT '',
        group_id INTEGER,
        created_at INTEGER NOT NULL DEFAULT 0,
        interval_enabled INTEGER NOT NULL DEFAULT 0,
        interval_days INTEGER,
        uuid TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT '',
        origin_type INTEGER NOT NULL DEFAULT 0,
        origin_source_uuid TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE place_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        calendar_id TEXT,
        include_notes INTEGER NOT NULL DEFAULT 1,
        include_persons INTEGER NOT NULL DEFAULT 1,
        include_activities INTEGER NOT NULL DEFAULT 1,
        is_auto_group INTEGER NOT NULL DEFAULT 0,
        place_type INTEGER NOT NULL DEFAULT 0,
        uuid TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE stays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        place_id INTEGER,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        notes TEXT NOT NULL DEFAULT '',
        calendar_event_id TEXT,
        address TEXT,
        status TEXT NOT NULL DEFAULT 'detecting',
        is_interval INTEGER NOT NULL DEFAULT 1,
        uuid TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (place_id) REFERENCES saved_places(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT '',
        uuid TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        uuid TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE stay_persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stay_id INTEGER NOT NULL,
        person_id INTEGER,
        name TEXT NOT NULL,
        uuid TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (stay_id) REFERENCES stays(id) ON DELETE CASCADE,
        FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE stay_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stay_id INTEGER NOT NULL,
        activity_id INTEGER,
        description TEXT NOT NULL,
        uuid TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (stay_id) REFERENCES stays(id) ON DELETE CASCADE,
        FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tracking_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_tracking_points_ts ON tracking_points(timestamp)',
    );
    await db.execute('''
      CREATE TABLE aktivitaeten (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        gps_interval_seconds INTEGER NOT NULL DEFAULT 15,
        stay_detection_seconds INTEGER NOT NULL DEFAULT 180,
        auto_place_seconds INTEGER NOT NULL DEFAULT 900,
        default_radius_meters REAL NOT NULL DEFAULT 50.0,
        auto_create_places INTEGER NOT NULL DEFAULT 1,
        auto_place_group_id INTEGER,
        default_place_group_id INTEGER,
        timeline_history_days INTEGER NOT NULL DEFAULT 7,
        search_country TEXT NOT NULL DEFAULT '',
        scheduler_color_range INTEGER NOT NULL DEFAULT 14,
        scheduler_group_ids TEXT NOT NULL DEFAULT '',
        uuid TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE web_sources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        experience TEXT NOT NULL DEFAULT '',
        api_key TEXT NOT NULL DEFAULT '',
        uuid TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE web_source_experiences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        web_source_uuid TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT 0,
        uuid TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  // ── Sync helpers ─────────────────────────────────────────────────────────

  /// Generates a new UUID v4 string.
  static String generateUuid() => _uuid.v4();

  /// Returns a map enriched with [uuid] (if blank), [updated_at], and
  /// [device_id] (if provided).
  Map<String, dynamic> _withSyncFields(
    Map<String, dynamic> map,
    String deviceId,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      ...map,
      'uuid': (map['uuid'] as String?)?.isNotEmpty == true
          ? map['uuid']
          : generateUuid(),
      'updated_at': now,
      'device_id': deviceId,
    };
  }

  // ── SavedPlaces ──────────────────────────────────────────────────────────

  Future<int> insertPlace(SavedPlace place, {String deviceId = ''}) async {
    final db = await database;
    return db.insert('saved_places', _withSyncFields(place.toMap(), deviceId));
  }

  Future<List<SavedPlace>> loadAllPlaces() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT sp.*,
             COALESCE(pg.place_type, 0) AS place_type
      FROM saved_places sp
      LEFT JOIN place_groups pg ON sp.group_id = pg.id
      WHERE sp.deleted_at IS NULL
    ''');
    return rows.map(SavedPlace.fromMap).toList();
  }

  Future<void> updatePlace(SavedPlace place, {String deviceId = ''}) async {
    final db = await database;
    await db.update(
      'saved_places',
      _withSyncFields(place.toMap(), deviceId),
      where: 'id = ?',
      whereArgs: [place.id],
    );
  }

  Future<void> deletePlace(int id) async {
    final db = await database;
    await db.delete('saved_places', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns the number of completed stays at [placeId].
  Future<int> visitCountForPlace(int placeId) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM stays WHERE place_id = ? AND status = 'completed'",
      [placeId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Returns the start_time of the most recent completed stay at [placeId]
  /// that counts toward the interval (is_interval = 1), or null.
  Future<int?> lastVisitedAtForPlace(int placeId) async {
    final db = await database;
    final rows = await db.query(
      'stays',
      columns: ['start_time'],
      where: "place_id = ? AND status = 'completed' AND is_interval = 1",
      whereArgs: [placeId],
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['start_time'] as int?;
  }

  /// Returns the most recent completed [Stay] at [placeId], or null.
  Future<Stay?> lastCompletedStayForPlace(int placeId) async {
    final db = await database;
    final rows = await db.query(
      'stays',
      where: "place_id = ? AND status = 'completed'",
      whereArgs: [placeId],
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Stay.fromMap(rows.first);
  }

  /// Returns distinct person names that appeared in completed stays at [placeId].
  Future<List<String>> loadDistinctPersonNamesForPlace(int placeId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT sp.name
      FROM stay_persons sp
      JOIN stays s ON s.id = sp.stay_id
      WHERE s.place_id = ? AND s.status = 'completed'
      ORDER BY sp.name ASC
      ''',
      [placeId],
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  // ── PlaceGroups ──────────────────────────────────────────────────────────

  Future<int> insertPlaceGroup(PlaceGroup group) async {
    final db = await database;
    return db.insert('place_groups', group.toMap());
  }

  Future<List<PlaceGroup>> loadAllPlaceGroups() async {
    final db = await database;
    final rows = await db.query('place_groups', orderBy: 'name ASC');
    return rows.map(PlaceGroup.fromMap).toList();
  }

  Future<PlaceGroup?> loadPlaceGroup(int id) async {
    final db = await database;
    final rows = await db.query(
      'place_groups',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return PlaceGroup.fromMap(rows.first);
  }

  Future<void> updatePlaceGroup(PlaceGroup group) async {
    final db = await database;
    await db.update(
      'place_groups',
      group.toMap(),
      where: 'id = ?',
      whereArgs: [group.id],
    );
  }

  Future<void> deletePlaceGroup(int id) async {
    final db = await database;
    await db.delete('place_groups', where: 'id = ?', whereArgs: [id]);
  }

  // ── Stays ────────────────────────────────────────────────────────────────

  Future<int> insertStay(Stay stay) async {
    final db = await database;
    return db.insert('stays', stay.toMap());
  }

  Future<List<Stay>> loadAllStays() async {
    final db = await database;
    final rows = await db.query('stays', orderBy: 'start_time DESC');
    return rows.map(Stay.fromMap).toList();
  }

  Future<List<Stay>> loadRecentCompletedStays({int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'stays',
      where: "status = 'completed'",
      orderBy: 'start_time DESC',
      limit: limit,
    );
    return rows.map(Stay.fromMap).toList();
  }

  Future<List<Stay>> loadCompletedStays() async {
    final db = await database;
    final rows = await db.query(
      'stays',
      where: "status = 'completed'",
      orderBy: 'start_time DESC',
    );
    return rows.map(Stay.fromMap).toList();
  }

  Future<Stay?> loadActiveStay() async {
    final db = await database;
    final rows = await db.query(
      'stays',
      where: "status != 'completed'",
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Stay.fromMap(rows.first);
  }

  Future<List<Stay>> loadStaysForPlace(int placeId) async {
    final db = await database;
    final rows = await db.query(
      'stays',
      where: 'place_id = ?',
      whereArgs: [placeId],
      orderBy: 'start_time DESC',
    );
    return rows.map(Stay.fromMap).toList();
  }

  Future<void> updateStay(Stay stay) async {
    final db = await database;
    await db.update(
      'stays',
      stay.toMap(),
      where: 'id = ?',
      whereArgs: [stay.id],
    );
  }

  Future<void> deleteStay(int id) async {
    final db = await database;
    await db.delete('stays', where: 'id = ?', whereArgs: [id]);
  }

  // ── Persons ──────────────────────────────────────────────────────────────

  Future<int> insertPerson(Person person) async {
    final db = await database;
    return db.insert('persons', person.toMap());
  }

  Future<List<Person>> loadAllPersons() async {
    final db = await database;
    final rows = await db.query('persons', orderBy: 'name ASC');
    return rows.map(Person.fromMap).toList();
  }

  Future<void> updatePerson(Person person) async {
    final db = await database;
    await db.update(
      'persons',
      person.toMap(),
      where: 'id = ?',
      whereArgs: [person.id],
    );
  }

  Future<void> deletePerson(int id) async {
    final db = await database;
    await db.delete('persons', where: 'id = ?', whereArgs: [id]);
  }

  // ── Activities ───────────────────────────────────────────────────────────

  Future<int> insertActivity(Activity activity) async {
    final db = await database;
    return db.insert('activities', activity.toMap());
  }

  Future<List<Activity>> loadAllActivities() async {
    final db = await database;
    final rows = await db.query('activities', orderBy: 'name ASC');
    return rows.map(Activity.fromMap).toList();
  }

  Future<void> updateActivity(Activity activity) async {
    final db = await database;
    await db.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  Future<void> deleteActivity(int id) async {
    final db = await database;
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  // ── StayPersons ──────────────────────────────────────────────────────────

  Future<int> insertStayPerson(StayPerson sp) async {
    final db = await database;
    return db.insert('stay_persons', sp.toMap());
  }

  Future<List<StayPerson>> loadPersonsForStay(int stayId) async {
    final db = await database;
    final rows = await db.query(
      'stay_persons',
      where: 'stay_id = ?',
      whereArgs: [stayId],
    );
    return rows.map(StayPerson.fromMap).toList();
  }

  Future<void> deletePersonsForStay(int stayId) async {
    final db = await database;
    await db.delete('stay_persons', where: 'stay_id = ?', whereArgs: [stayId]);
  }

  Future<void> deleteStayPerson(int id) async {
    final db = await database;
    await db.delete('stay_persons', where: 'id = ?', whereArgs: [id]);
  }

  // ── StayActivities ───────────────────────────────────────────────────────

  Future<int> insertStayActivity(StayActivity sa) async {
    final db = await database;
    return db.insert('stay_activities', sa.toMap());
  }

  Future<List<StayActivity>> loadActivitiesForStay(int stayId) async {
    final db = await database;
    final rows = await db.query(
      'stay_activities',
      where: 'stay_id = ?',
      whereArgs: [stayId],
    );
    return rows.map(StayActivity.fromMap).toList();
  }

  Future<void> deleteActivitiesForStay(int stayId) async {
    final db = await database;
    await db.delete(
      'stay_activities',
      where: 'stay_id = ?',
      whereArgs: [stayId],
    );
  }

  Future<void> deleteStayActivity(int id) async {
    final db = await database;
    await db.delete('stay_activities', where: 'id = ?', whereArgs: [id]);
  }

  // ── TrackingPoints ───────────────────────────────────────────────────────

  Future<int> insertTrackingPoint(TrackingPoint point) async {
    final db = await database;
    return db.insert('tracking_points', point.toMap());
  }

  Future<List<TrackingPoint>> loadTrackingPointsSince(
    int sinceTimestamp,
  ) async {
    final db = await database;
    final rows = await db.query(
      'tracking_points',
      where: 'timestamp >= ?',
      whereArgs: [sinceTimestamp],
      orderBy: 'timestamp ASC',
    );
    return rows.map(TrackingPoint.fromMap).toList();
  }

  Future<void> deleteTrackingPointsOlderThan(int beforeTimestamp) async {
    final db = await database;
    await db.delete(
      'tracking_points',
      where: 'timestamp < ?',
      whereArgs: [beforeTimestamp],
    );
  }

  Future<void> cleanupOldTrackingPoints() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    await deleteTrackingPointsOlderThan(cutoff);
  }

  Future<void> deleteAllTrackingPoints() async {
    final db = await database;
    await db.delete('tracking_points');
  }

  // ── Aktivitaeten ─────────────────────────────────────────────────────────

  Future<int> insertAktivitaet(Aktivitaet a) async {
    final db = await database;
    return db.insert('aktivitaeten', a.toMap());
  }

  Future<List<Aktivitaet>> loadAllAktivitaeten() async {
    final db = await database;
    final rows = await db.query('aktivitaeten', orderBy: 'id ASC');
    return rows.map(Aktivitaet.fromMap).toList();
  }

  Future<Aktivitaet?> loadAktivitaet(int id) async {
    final db = await database;
    final rows = await db.query(
      'aktivitaeten',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Aktivitaet.fromMap(rows.first);
  }

  Future<void> updateAktivitaet(Aktivitaet a) async {
    final db = await database;
    await db.update(
      'aktivitaeten',
      a.toMap(),
      where: 'id = ?',
      whereArgs: [a.id],
    );
  }

  Future<void> deleteAktivitaet(int id) async {
    final db = await database;
    await db.delete('aktivitaeten', where: 'id = ?', whereArgs: [id]);
  }

  // ── Dump / Import ─────────────────────────────────────────────────────────

  /// Generates a complete SQL dump of the database with CREATE TABLE IF NOT
  /// EXISTS and INSERT OR REPLACE statements for every table.
  Future<String> generateDump() async {
    final db = await database;
    final buf = StringBuffer();
    buf.writeln('-- Chaos Tours DB Dump');
    buf.writeln('-- ${DateTime.now().toIso8601String()}');
    buf.writeln();
    buf.writeln('PRAGMA foreign_keys = OFF;');
    buf.writeln();

    final tables = await db.rawQuery(
      "SELECT name, sql FROM sqlite_master "
      "WHERE type='table' AND name NOT LIKE 'sqlite_%' "
      "ORDER BY rowid",
    );

    for (final t in tables) {
      final name = t['name'] as String;
      final sql = (t['sql'] as String).replaceFirst(
        'CREATE TABLE',
        'CREATE TABLE IF NOT EXISTS',
      );
      buf.writeln('$sql;');
      buf.writeln();

      final rows = await db.query(name);
      for (final row in rows) {
        final cols = row.keys.join(', ');
        final vals = row.values
            .map((v) {
              if (v == null) return 'NULL';
              if (v is int || v is double) return v.toString();
              return "'${(v as String).replaceAll("'", "''")}'";
            })
            .join(', ');
        buf.writeln('INSERT OR REPLACE INTO $name ($cols) VALUES ($vals);');
      }
      buf.writeln();
    }

    final indices = await db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type='index' AND sql IS NOT NULL",
    );
    for (final idx in indices) {
      buf.writeln('${idx['sql']};');
    }
    buf.writeln();
    buf.writeln('PRAGMA foreign_keys = ON;');
    return buf.toString();
  }

  /// Executes [sql] dump statements inside a transaction.
  /// If [clearFirst] is true, all table data is deleted before importing.
  Future<void> importDump(String sql, {bool clearFirst = false}) async {
    final db = await database;

    // Parse statements (split on ";\n" to avoid splitting inside string values)
    final statements = sql
        .split(RegExp(r';\s*\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('--'))
        .toList();

    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      if (clearFirst) {
        final tables = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'",
        );
        for (final t in tables) {
          await txn.execute('DELETE FROM ${t['name']}');
        }
      }
      for (final stmt in statements) {
        if (stmt.toUpperCase().startsWith('PRAGMA')) continue;
        await txn.execute(stmt);
      }
      await txn.execute('PRAGMA foreign_keys = ON');
    });
  }

  // ── File-level DB operations ─────────────────────────────────────────────

  /// Returns the absolute path to the SQLite database file.
  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'chaos_tours.db');
  }

  /// Closes the current DB connection, replaces the file with [sourcePath],
  /// and reopens the database.
  Future<void> importDatabaseFile(String sourcePath) async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    final targetPath = await getDatabaseFilePath();
    await File(sourcePath).copy(targetPath);
    _db = await _openDatabase();
  }

  /// Deletes all rows from every user table without dropping the schema.
  Future<void> resetAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      final tables = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      for (final t in tables) {
        await txn.execute('DELETE FROM ${t['name']}');
      }
      await txn.execute('PRAGMA foreign_keys = ON');
    });
  }

  // ── WebSources ────────────────────────────────────────────────────────────

  Future<int> insertWebSource(WebSource source, {String deviceId = ''}) async {
    final db = await database;
    return db.insert('web_sources', _withSyncFields(source.toMap(), deviceId));
  }

  Future<List<WebSource>> loadAllWebSources() async {
    final db = await database;
    final rows = await db.query(
      'web_sources',
      where: 'deleted_at IS NULL',
      orderBy: 'name ASC',
    );
    return rows.map(WebSource.fromMap).toList();
  }

  Future<void> updateWebSource(WebSource source, {String deviceId = ''}) async {
    final db = await database;
    await db.update(
      'web_sources',
      _withSyncFields(source.toMap(), deviceId),
      where: 'id = ?',
      whereArgs: [source.id],
    );
  }

  Future<void> deleteWebSource(int id) async {
    final db = await database;
    await db.delete('web_sources', where: 'id = ?', whereArgs: [id]);
  }

  // ── WebSourceExperiences ─────────────────────────────────────────────────

  Future<int> insertWebSourceExperience(
    WebSourceExperience exp, {
    String deviceId = '',
  }) async {
    final db = await database;
    return db.insert(
      'web_source_experiences',
      _withSyncFields(exp.toMap(), deviceId),
    );
  }

  Future<List<WebSourceExperience>> loadExperiencesForWebSource(
    String webSourceUuid,
  ) async {
    final db = await database;
    final rows = await db.query(
      'web_source_experiences',
      where: 'web_source_uuid = ? AND deleted_at IS NULL',
      whereArgs: [webSourceUuid],
      orderBy: 'created_at DESC',
    );
    return rows.map(WebSourceExperience.fromMap).toList();
  }

  Future<void> updateWebSourceExperience(
    WebSourceExperience exp, {
    String deviceId = '',
  }) async {
    final db = await database;
    await db.update(
      'web_source_experiences',
      _withSyncFields(exp.toMap(), deviceId),
      where: 'id = ?',
      whereArgs: [exp.id],
    );
  }

  Future<void> softDeleteWebSourceExperience(
    int id, {
    String deviceId = '',
  }) async {
    final db = await database;
    await db.update(
      'web_source_experiences',
      {
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Soft-deletes a web_source by setting deleted_at.
  Future<void> softDeleteWebSource(int id, {String deviceId = ''}) async {
    final db = await database;
    await db.update(
      'web_sources',
      {
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Sync queries ──────────────────────────────────────────────────────────

  /// Returns all rows from [table] with updated_at > [since] (for push/pull).
  Future<List<Map<String, dynamic>>> loadChangedRows(
    String table,
    int since,
  ) async {
    final db = await database;
    return db.query(table, where: 'updated_at > ?', whereArgs: [since]);
  }

  /// Upserts a row by its uuid (used during pull from server).
  /// [options] controls whether inserts, edits, and deletes are allowed.
  Future<void> upsertByUuid(
    String table,
    Map<String, dynamic> row, {
    SyncOptions options = SyncOptions.all,
  }) async {
    final db = await database;
    final uuid = row['uuid'] as String?;
    if (uuid == null || uuid.isEmpty) return;

    final existing = await db.query(
      table,
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    if (existing.isEmpty) {
      if (!options.allowInsert) return;
      // Insert without the incoming integer id to avoid conflicts.
      final toInsert = Map<String, dynamic>.from(row)..remove('id');
      await db.insert(table, toInsert);
    } else {
      final localUpdatedAt = (existing.first['updated_at'] as int?) ?? 0;
      final remoteUpdatedAt = (row['updated_at'] as int?) ?? 0;
      if (remoteUpdatedAt > localUpdatedAt) {
        // Check if this is a deletion (deleted_at being set).
        final isDelete =
            row['deleted_at'] != null && existing.first['deleted_at'] == null;
        if (isDelete && !options.allowDelete) return;
        if (!isDelete && !options.allowEdit) return;
        final toUpdate = Map<String, dynamic>.from(row)..remove('id');
        await db.update(table, toUpdate, where: 'uuid = ?', whereArgs: [uuid]);
      }
    }
  }

  // ── ensureDefaultAktivitaet / ensureDefaultGroups ─────────────────────────

  /// Ensures at least one Aktivitaet exists. Creates a default one if the
  /// table is empty and returns its id.
  Future<int> ensureDefaultAktivitaet({
    int gpsInterval = 15,
    int stayDetection = 180,
    int autoPlace = 900,
    double radius = 50.0,
    bool autoCreate = true,
    int? autoPlaceGroupId,
    int? defaultPlaceGroupId,
  }) async {
    final all = await loadAllAktivitaeten();
    if (all.isNotEmpty) return all.first.id!;
    return insertAktivitaet(
      Aktivitaet(
        name: 'Standard',
        gpsIntervalSeconds: gpsInterval,
        stayDetectionSeconds: stayDetection,
        autoPlaceSeconds: autoPlace,
        defaultRadiusMeters: radius,
        autoCreatePlaces: autoCreate,
        autoPlaceGroupId: autoPlaceGroupId,
        defaultPlaceGroupId: defaultPlaceGroupId,
      ),
    );
  }

  /// Creates default place groups on first install (when no groups exist yet).
  /// Returns the IDs of the "Automatisch" group and the "Standard" group,
  /// or null if groups already existed.
  Future<({int autoGroupId, int defaultGroupId})?> ensureDefaultGroups() async {
    final existing = await loadAllPlaceGroups();
    if (existing.isNotEmpty) return null;

    // Import PlaceType through the model layer.
    final autoId = await insertPlaceGroup(
      PlaceGroup(
        name: 'Automatisch',
        placeType: PlaceType.private,
        isAutoGroup: true,
      ),
    );
    final defId = await insertPlaceGroup(
      PlaceGroup(name: 'Standard', placeType: PlaceType.public),
    );
    return (autoGroupId: autoId, defaultGroupId: defId);
  }
}
