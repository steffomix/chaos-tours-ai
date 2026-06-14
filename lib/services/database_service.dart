import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/aktivitaet.dart';
import '../models/activity.dart';
import '../models/person.dart';
import '../models/place_experience.dart';
import '../models/place_group.dart';
import '../models/saved_place.dart';
import '../models/stay.dart';
import '../models/stay_activity.dart';
import '../models/stay_person.dart';
import '../models/place_photo.dart';
import '../models/sync_source.dart';
import '../models/sync_source_experience.dart';
import '../models/telegram_connection.dart';
import '../models/tracking_point.dart';
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

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE place_groups (
        uuid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        calendar_id TEXT,
        telegram_connection_uuid TEXT,
        include_notes INTEGER NOT NULL DEFAULT 1,
        include_persons INTEGER NOT NULL DEFAULT 1,
        include_activities INTEGER NOT NULL DEFAULT 1,
        is_auto_group INTEGER NOT NULL DEFAULT 0,
        place_type INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE saved_places (
        uuid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        radius REAL NOT NULL DEFAULT 50.0,
        notes TEXT NOT NULL DEFAULT '',
        group_uuid TEXT,
        created_at INTEGER NOT NULL DEFAULT 0,
        interval_enabled INTEGER NOT NULL DEFAULT 0,
        interval_days INTEGER,
        origin_type INTEGER NOT NULL DEFAULT 0,
        origin_source_uuid TEXT,
        website TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (group_uuid) REFERENCES place_groups(uuid) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE stays (
        uuid TEXT PRIMARY KEY,
        place_uuid TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        notes TEXT NOT NULL DEFAULT '',
        calendar_event_id TEXT,
        telegram_message_id TEXT,
        address TEXT,
        status TEXT NOT NULL DEFAULT 'detecting',
        is_interval INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (place_uuid) REFERENCES saved_places(uuid) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE persons (
        uuid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE activities (
        uuid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE stay_persons (
        uuid TEXT PRIMARY KEY,
        stay_uuid TEXT NOT NULL,
        person_uuid TEXT,
        name TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (stay_uuid) REFERENCES stays(uuid) ON DELETE CASCADE,
        FOREIGN KEY (person_uuid) REFERENCES persons(uuid) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE stay_activities (
        uuid TEXT PRIMARY KEY,
        stay_uuid TEXT NOT NULL,
        activity_uuid TEXT,
        description TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (stay_uuid) REFERENCES stays(uuid) ON DELETE CASCADE,
        FOREIGN KEY (activity_uuid) REFERENCES activities(uuid) ON DELETE SET NULL
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
        uuid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        gps_interval_seconds INTEGER NOT NULL DEFAULT 15,
        stay_detection_seconds INTEGER NOT NULL DEFAULT 180,
        auto_place_seconds INTEGER NOT NULL DEFAULT 900,
        default_radius_meters REAL NOT NULL DEFAULT 50.0,
        auto_create_places INTEGER NOT NULL DEFAULT 1,
        auto_place_group_uuid TEXT,
        default_place_group_uuid TEXT,
        timeline_history_days INTEGER NOT NULL DEFAULT 7,
        search_country TEXT NOT NULL DEFAULT '',
        scheduler_color_range INTEGER NOT NULL DEFAULT 14,
        scheduler_group_ids TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_sources (
        uuid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sync_url TEXT NOT NULL DEFAULT '',
        api_key TEXT NOT NULL DEFAULT '',
        info_url TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        sync_options TEXT NOT NULL DEFAULT '{}',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE place_experiences (
        uuid TEXT PRIMARY KEY,
        saved_place_uuid TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        rating_dangerous_friendly INTEGER NOT NULL DEFAULT 0,
        rating_fraud_reliable INTEGER NOT NULL DEFAULT 0,
        rating_dismissive_accommodation INTEGER NOT NULL DEFAULT 0,
        rating_food INTEGER NOT NULL DEFAULT 0,
        rating_equipment INTEGER NOT NULL DEFAULT 0,
        rating_transport INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_source_experiences (
        uuid TEXT PRIMARY KEY,
        sync_source_uuid TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS place_photos (
        uuid TEXT PRIMARY KEY,
        place_uuid TEXT,
        stay_uuid TEXT,
        caption TEXT NOT NULL DEFAULT '',
        taken_at INTEGER NOT NULL DEFAULT 0,
        photo_data TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (place_uuid) REFERENCES saved_places(uuid) ON DELETE CASCADE,
        FOREIGN KEY (stay_uuid) REFERENCES stays(uuid) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_place_photos_place ON place_photos(place_uuid)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_place_photos_stay ON place_photos(stay_uuid)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS telegram_connections (
        uuid TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        chat_id TEXT NOT NULL DEFAULT '',
        bot_token TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        device_id TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add telegram_connections table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS telegram_connections (
          uuid TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          chat_id TEXT NOT NULL DEFAULT '',
          bot_token TEXT NOT NULL DEFAULT '',
          updated_at INTEGER NOT NULL DEFAULT 0,
          deleted_at INTEGER,
          device_id TEXT NOT NULL DEFAULT ''
        )
      ''');
      // Add telegram_connection_uuid column to place_groups
      await db.execute(
        'ALTER TABLE place_groups ADD COLUMN telegram_connection_uuid TEXT',
      );
    }
    if (oldVersion < 3) {
      // Add telegram_message_id column to stays
      await db.execute('ALTER TABLE stays ADD COLUMN telegram_message_id TEXT');
    }
  }

  // ── Sync helpers ─────────────────────────────────────────────────────────

  /// Generates a new UUID v4 string.
  static String generateUuid() => _uuid.v4();

  /// Returns a map enriched with [updated_at] and [device_id].
  /// If the map has no 'uuid' or an empty one, a new UUID is generated.
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

  Future<String> insertPlace(SavedPlace place, {String deviceId = ''}) async {
    final db = await database;
    final map = _withSyncFields(place.toMap(), deviceId);
    await db.insert(
      'saved_places',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
  }

  Future<List<SavedPlace>> loadAllPlaces() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT sp.*,
             COALESCE(pg.place_type, 0) AS place_type
      FROM saved_places sp
      LEFT JOIN place_groups pg ON sp.group_uuid = pg.uuid
      WHERE sp.deleted_at IS NULL
    ''');
    return rows.map(SavedPlace.fromMap).toList();
  }

  Future<void> updatePlace(SavedPlace place, {String deviceId = ''}) async {
    final db = await database;
    await db.update(
      'saved_places',
      _withSyncFields(place.toMap(), deviceId),
      where: 'uuid = ?',
      whereArgs: [place.uuid],
    );
  }

  Future<void> deletePlace(String uuid) async {
    final db = await database;
    await db.delete('saved_places', where: 'uuid = ?', whereArgs: [uuid]);
  }

  /// Returns the number of completed stays at [placeUuid].
  Future<int> visitCountForPlace(String placeUuid) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM stays WHERE place_uuid = ? AND status = 'completed'",
      [placeUuid],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Returns the start_time of the most recent completed stay at [placeUuid]
  /// that counts toward the interval (is_interval = 1), or null.
  Future<int?> lastVisitedAtForPlace(String placeUuid) async {
    final db = await database;
    final rows = await db.query(
      'stays',
      columns: ['start_time'],
      where: "place_uuid = ? AND status = 'completed' AND is_interval = 1",
      whereArgs: [placeUuid],
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['start_time'] as int?;
  }

  /// Returns the most recent completed [Stay] at [placeUuid], or null.
  Future<Stay?> lastCompletedStayForPlace(String placeUuid) async {
    final db = await database;
    final rows = await db.query(
      'stays',
      where: "place_uuid = ? AND status = 'completed'",
      whereArgs: [placeUuid],
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Stay.fromMap(rows.first);
  }

  /// Returns distinct person names that appeared in completed stays at [placeUuid].
  Future<List<String>> loadDistinctPersonNamesForPlace(String placeUuid) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT sp.name
      FROM stay_persons sp
      JOIN stays s ON s.uuid = sp.stay_uuid
      WHERE s.place_uuid = ? AND s.status = 'completed'
      ORDER BY sp.name ASC
      ''',
      [placeUuid],
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  // ── PlaceGroups ──────────────────────────────────────────────────────────

  Future<String> insertPlaceGroup(PlaceGroup group) async {
    final db = await database;
    final map = _withSyncFields(group.toMap(), '');
    await db.insert(
      'place_groups',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
  }

  Future<List<PlaceGroup>> loadAllPlaceGroups() async {
    final db = await database;
    final rows = await db.query('place_groups', orderBy: 'name ASC');
    return rows.map(PlaceGroup.fromMap).toList();
  }

  Future<PlaceGroup?> loadPlaceGroup(String uuid) async {
    final db = await database;
    final rows = await db.query(
      'place_groups',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (rows.isEmpty) return null;
    return PlaceGroup.fromMap(rows.first);
  }

  Future<void> updatePlaceGroup(PlaceGroup group) async {
    final db = await database;
    await db.update(
      'place_groups',
      _withSyncFields(group.toMap(), ''),
      where: 'uuid = ?',
      whereArgs: [group.uuid],
    );
  }

  Future<void> deletePlaceGroup(String uuid) async {
    final db = await database;
    await db.delete('place_groups', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── Stays ────────────────────────────────────────────────────────────────

  Future<String> insertStay(Stay stay) async {
    final db = await database;
    final map = _withSyncFields(stay.toMap(), '');
    await db.insert('stays', map, conflictAlgorithm: ConflictAlgorithm.replace);
    return map['uuid'] as String;
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

  Future<List<Stay>> loadStaysForPlace(String placeUuid) async {
    final db = await database;
    final rows = await db.query(
      'stays',
      where: 'place_uuid = ?',
      whereArgs: [placeUuid],
      orderBy: 'start_time DESC',
    );
    return rows.map(Stay.fromMap).toList();
  }

  Future<void> updateStay(Stay stay) async {
    final db = await database;
    await db.update(
      'stays',
      _withSyncFields(stay.toMap(), ''),
      where: 'uuid = ?',
      whereArgs: [stay.uuid],
    );
  }

  Future<void> deleteStay(String uuid) async {
    final db = await database;
    await db.delete('stays', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── Persons ──────────────────────────────────────────────────────────────

  Future<String> insertPerson(Person person) async {
    final db = await database;
    final map = _withSyncFields(person.toMap(), '');
    await db.insert(
      'persons',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
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
      _withSyncFields(person.toMap(), ''),
      where: 'uuid = ?',
      whereArgs: [person.uuid],
    );
  }

  Future<void> deletePerson(String uuid) async {
    final db = await database;
    await db.delete('persons', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── Activities ───────────────────────────────────────────────────────────

  Future<String> insertActivity(Activity activity) async {
    final db = await database;
    final map = _withSyncFields(activity.toMap(), '');
    await db.insert(
      'activities',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
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
      _withSyncFields(activity.toMap(), ''),
      where: 'uuid = ?',
      whereArgs: [activity.uuid],
    );
  }

  Future<void> deleteActivity(String uuid) async {
    final db = await database;
    await db.delete('activities', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── StayPersons ──────────────────────────────────────────────────────────

  Future<String> insertStayPerson(StayPerson sp) async {
    final db = await database;
    final map = _withSyncFields(sp.toMap(), '');
    await db.insert(
      'stay_persons',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
  }

  Future<List<StayPerson>> loadPersonsForStay(String stayUuid) async {
    final db = await database;
    final rows = await db.query(
      'stay_persons',
      where: 'stay_uuid = ?',
      whereArgs: [stayUuid],
    );
    return rows.map(StayPerson.fromMap).toList();
  }

  Future<void> deletePersonsForStay(String stayUuid) async {
    final db = await database;
    await db.delete(
      'stay_persons',
      where: 'stay_uuid = ?',
      whereArgs: [stayUuid],
    );
  }

  Future<void> deleteStayPerson(String uuid) async {
    final db = await database;
    await db.delete('stay_persons', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── StayActivities ───────────────────────────────────────────────────────

  Future<String> insertStayActivity(StayActivity sa) async {
    final db = await database;
    final map = _withSyncFields(sa.toMap(), '');
    await db.insert(
      'stay_activities',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
  }

  Future<List<StayActivity>> loadActivitiesForStay(String stayUuid) async {
    final db = await database;
    final rows = await db.query(
      'stay_activities',
      where: 'stay_uuid = ?',
      whereArgs: [stayUuid],
    );
    return rows.map(StayActivity.fromMap).toList();
  }

  Future<void> deleteActivitiesForStay(String stayUuid) async {
    final db = await database;
    await db.delete(
      'stay_activities',
      where: 'stay_uuid = ?',
      whereArgs: [stayUuid],
    );
  }

  Future<void> deleteStayActivity(String uuid) async {
    final db = await database;
    await db.delete('stay_activities', where: 'uuid = ?', whereArgs: [uuid]);
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

  Future<String> insertAktivitaet(Aktivitaet a) async {
    final db = await database;
    final map = _withSyncFields(a.toMap(), '');
    await db.insert(
      'aktivitaeten',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
  }

  Future<List<Aktivitaet>> loadAllAktivitaeten() async {
    final db = await database;
    final rows = await db.query('aktivitaeten', orderBy: 'name ASC');
    return rows.map(Aktivitaet.fromMap).toList();
  }

  Future<Aktivitaet?> loadAktivitaet(String uuid) async {
    final db = await database;
    final rows = await db.query(
      'aktivitaeten',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (rows.isEmpty) return null;
    return Aktivitaet.fromMap(rows.first);
  }

  Future<void> updateAktivitaet(Aktivitaet a) async {
    final db = await database;
    await db.update(
      'aktivitaeten',
      _withSyncFields(a.toMap(), ''),
      where: 'uuid = ?',
      whereArgs: [a.uuid],
    );
  }

  Future<void> deleteAktivitaet(String uuid) async {
    final db = await database;
    await db.delete('aktivitaeten', where: 'uuid = ?', whereArgs: [uuid]);
  }

  // ── Dump / Import ─────────────────────────────────────────────────────────

  /// Generates a complete SQL dump of the database.
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
  Future<void> importDump(String sql, {bool clearFirst = false}) async {
    final db = await database;

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

  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'chaos_tours.db');
  }

  Future<void> importDatabaseFile(String sourcePath) async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    final targetPath = await getDatabaseFilePath();
    await File(sourcePath).copy(targetPath);
    _db = await _openDatabase();
  }

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

  // ── SyncSources ──────────────────────────────────────────────────────────

  Future<String> insertSyncSource(
    SyncSource source, {
    String deviceId = '',
  }) async {
    final db = await database;
    final map = _withSyncFields(source.toMap(), deviceId);
    await db.insert(
      'sync_sources',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
  }

  Future<List<SyncSource>> loadAllSyncSources() async {
    final db = await database;
    final rows = await db.query(
      'sync_sources',
      where: 'deleted_at IS NULL',
      orderBy: 'name ASC',
    );
    return rows.map(SyncSource.fromMap).toList();
  }

  Future<void> updateSyncSource(
    SyncSource source, {
    String deviceId = '',
  }) async {
    final db = await database;
    await db.update(
      'sync_sources',
      _withSyncFields(source.toMap(), deviceId),
      where: 'uuid = ?',
      whereArgs: [source.uuid],
    );
  }

  Future<void> softDeleteSyncSource(String uuid, {String deviceId = ''}) async {
    final db = await database;
    await db.update(
      'sync_sources',
      {
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // ── TelegramConnections ──────────────────────────────────────────────────

  Future<String> insertTelegramConnection(
    TelegramConnection conn, {
    String deviceId = '',
  }) async {
    final db = await database;
    final map = _withSyncFields(conn.toMap(), deviceId);
    await db.insert(
      'telegram_connections',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
  }

  Future<List<TelegramConnection>> loadAllTelegramConnections() async {
    final db = await database;
    final rows = await db.query(
      'telegram_connections',
      where: 'deleted_at IS NULL',
      orderBy: 'name ASC',
    );
    return rows.map(TelegramConnection.fromMap).toList();
  }

  Future<TelegramConnection?> loadTelegramConnection(String uuid) async {
    final db = await database;
    final rows = await db.query(
      'telegram_connections',
      where: 'uuid = ? AND deleted_at IS NULL',
      whereArgs: [uuid],
    );
    if (rows.isEmpty) return null;
    return TelegramConnection.fromMap(rows.first);
  }

  Future<void> updateTelegramConnection(
    TelegramConnection conn, {
    String deviceId = '',
  }) async {
    final db = await database;
    await db.update(
      'telegram_connections',
      _withSyncFields(conn.toMap(), deviceId),
      where: 'uuid = ?',
      whereArgs: [conn.uuid],
    );
  }

  Future<void> softDeleteTelegramConnection(
    String uuid, {
    String deviceId = '',
  }) async {
    final db = await database;
    await db.update(
      'telegram_connections',
      {
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // ── PlaceExperiences ─────────────────────────────────────────────────────

  Future<String> insertPlaceExperience(
    PlaceExperience exp, {
    String deviceId = '',
  }) async {
    final db = await database;
    final map = _withSyncFields(exp.toMap(), deviceId);
    await db.insert(
      'place_experiences',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
  }

  Future<List<PlaceExperience>> loadExperiencesForPlace(
    String savedPlaceUuid,
  ) async {
    final db = await database;
    final rows = await db.query(
      'place_experiences',
      where: 'saved_place_uuid = ? AND deleted_at IS NULL',
      whereArgs: [savedPlaceUuid],
      orderBy: 'created_at DESC',
    );
    return rows.map(PlaceExperience.fromMap).toList();
  }

  Future<Map<String, double>> loadAverageRatingsForAllPlaces() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT saved_place_uuid,
             AVG(rating_dangerous_friendly) AS r1,
             AVG(rating_fraud_reliable) AS r2,
             AVG(rating_dismissive_accommodation) AS r3,
             AVG(rating_food) AS r4,
             AVG(rating_equipment) AS r5,
             AVG(rating_transport) AS r6
      FROM place_experiences
      WHERE deleted_at IS NULL
      GROUP BY saved_place_uuid
    ''');
    return {
      for (final r in rows)
        r['saved_place_uuid'] as String:
            (((r['r1'] as num?) ?? 0) +
                ((r['r2'] as num?) ?? 0) +
                ((r['r3'] as num?) ?? 0) +
                ((r['r4'] as num?) ?? 0) +
                ((r['r5'] as num?) ?? 0) +
                ((r['r6'] as num?) ?? 0)) /
            6.0,
    };
  }

  Future<Map<String, double>> loadDimensionRatingsForPlace(
    String savedPlaceUuid,
  ) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        AVG(rating_dangerous_friendly) AS r1,
        AVG(rating_fraud_reliable) AS r2,
        AVG(rating_dismissive_accommodation) AS r3,
        AVG(rating_food) AS r4,
        AVG(rating_equipment) AS r5,
        AVG(rating_transport) AS r6
      FROM place_experiences
      WHERE saved_place_uuid = ? AND deleted_at IS NULL
    ''',
      [savedPlaceUuid],
    );
    if (rows.isEmpty) return {};
    final r = rows.first;
    return {
      'dangerous_friendly': ((r['r1'] as num?) ?? 0).toDouble(),
      'fraud_reliable': ((r['r2'] as num?) ?? 0).toDouble(),
      'dismissive_accommodation': ((r['r3'] as num?) ?? 0).toDouble(),
      'food': ((r['r4'] as num?) ?? 0).toDouble(),
      'equipment': ((r['r5'] as num?) ?? 0).toDouble(),
      'transport': ((r['r6'] as num?) ?? 0).toDouble(),
    };
  }

  Future<void> updatePlaceExperience(
    PlaceExperience exp, {
    String deviceId = '',
  }) async {
    final db = await database;
    await db.update(
      'place_experiences',
      _withSyncFields(exp.toMap(), deviceId),
      where: 'uuid = ?',
      whereArgs: [exp.uuid],
    );
  }

  Future<void> softDeletePlaceExperience(
    String uuid, {
    String deviceId = '',
  }) async {
    final db = await database;
    await db.update(
      'place_experiences',
      {
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // ── SyncSourceExperiences ─────────────────────────────────────────────────

  Future<String> insertSyncSourceExperience(
    SyncSourceExperience exp, {
    String deviceId = '',
  }) async {
    final db = await database;
    final map = _withSyncFields(exp.toMap(), deviceId);
    await db.insert(
      'sync_source_experiences',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
  }

  Future<List<SyncSourceExperience>> loadExperiencesForSyncSource(
    String syncSourceUuid,
  ) async {
    final db = await database;
    final rows = await db.query(
      'sync_source_experiences',
      where: 'sync_source_uuid = ? AND deleted_at IS NULL',
      whereArgs: [syncSourceUuid],
      orderBy: 'created_at DESC',
    );
    return rows.map(SyncSourceExperience.fromMap).toList();
  }

  Future<void> softDeleteSyncSourceExperience(
    String uuid, {
    String deviceId = '',
  }) async {
    final db = await database;
    await db.update(
      'sync_source_experiences',
      {
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // ── PlacePhotos ───────────────────────────────────────────────────────────

  Future<String> insertPlacePhoto(
    PlacePhoto photo, {
    String deviceId = '',
  }) async {
    final db = await database;
    final map = _withSyncFields(photo.toMap(), deviceId);
    await db.insert(
      'place_photos',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return map['uuid'] as String;
  }

  Future<List<PlacePhoto>> loadAllPhotos() async {
    final db = await database;
    final rows = await db.query(
      'place_photos',
      where: 'deleted_at IS NULL',
      orderBy: 'taken_at DESC',
    );
    return rows.map(PlacePhoto.fromMap).toList();
  }

  /// All photos for a place, including photos of its stays.
  Future<List<PlacePhoto>> loadPhotosForPlace(String placeUuid) async {
    final db = await database;
    // Collect stay UUIDs for this place.
    final stayRows = await db.query(
      'stays',
      columns: ['uuid'],
      where: 'place_uuid = ? AND deleted_at IS NULL',
      whereArgs: [placeUuid],
    );
    final stayUuids = stayRows.map((r) => r['uuid'] as String).toList();

    if (stayUuids.isEmpty) {
      final rows = await db.query(
        'place_photos',
        where: 'place_uuid = ? AND deleted_at IS NULL',
        whereArgs: [placeUuid],
        orderBy: 'taken_at DESC',
      );
      return rows.map(PlacePhoto.fromMap).toList();
    }

    final placeholders = stayUuids.map((_) => '?').join(',');
    final rows = await db.rawQuery(
      '''SELECT * FROM place_photos
         WHERE deleted_at IS NULL
           AND (place_uuid = ? OR stay_uuid IN ($placeholders))
         ORDER BY taken_at DESC''',
      [placeUuid, ...stayUuids],
    );
    return rows.map(PlacePhoto.fromMap).toList();
  }

  Future<List<PlacePhoto>> loadPhotosForStay(String stayUuid) async {
    final db = await database;
    final rows = await db.query(
      'place_photos',
      where: 'stay_uuid = ? AND deleted_at IS NULL',
      whereArgs: [stayUuid],
      orderBy: 'taken_at DESC',
    );
    return rows.map(PlacePhoto.fromMap).toList();
  }

  Future<void> updatePlacePhotoCaption(
    String uuid,
    String caption, {
    String deviceId = '',
  }) async {
    final db = await database;
    await db.update(
      'place_photos',
      {
        'caption': caption,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> softDeletePlacePhoto(String uuid, {String deviceId = ''}) async {
    final db = await database;
    await db.update(
      'place_photos',
      {
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  // ── Sync queries ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadChangedRows(
    String table,
    int since,
  ) async {
    final db = await database;
    return db.query(table, where: 'updated_at > ?', whereArgs: [since]);
  }

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
      await db.insert(
        table,
        Map<String, dynamic>.from(row),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      final localUpdatedAt = (existing.first['updated_at'] as int?) ?? 0;
      final remoteUpdatedAt = (row['updated_at'] as int?) ?? 0;
      if (remoteUpdatedAt > localUpdatedAt) {
        final isDelete =
            row['deleted_at'] != null && existing.first['deleted_at'] == null;
        if (isDelete && !options.allowDelete) return;
        if (!isDelete && !options.allowEdit) return;
        await db.update(
          table,
          Map<String, dynamic>.from(row),
          where: 'uuid = ?',
          whereArgs: [uuid],
        );
      }
    }
  }

  // ── ensureDefaultAktivitaet / ensureDefaultGroups ─────────────────────────

  Future<String> ensureDefaultAktivitaet({
    int gpsInterval = 15,
    int stayDetection = 180,
    int autoPlace = 900,
    double radius = 50.0,
    bool autoCreate = true,
    String? autoPlaceGroupUuid,
    String? defaultPlaceGroupUuid,
  }) async {
    final all = await loadAllAktivitaeten();
    if (all.isNotEmpty) return all.first.uuid;
    return insertAktivitaet(
      Aktivitaet(
        name: 'Standard',
        gpsIntervalSeconds: gpsInterval,
        stayDetectionSeconds: stayDetection,
        autoPlaceSeconds: autoPlace,
        defaultRadiusMeters: radius,
        autoCreatePlaces: autoCreate,
        autoPlaceGroupUuid: autoPlaceGroupUuid,
        defaultPlaceGroupUuid: defaultPlaceGroupUuid,
      ),
    );
  }

  Future<({String autoGroupUuid, String defaultGroupUuid})?>
  ensureDefaultGroups() async {
    final existing = await loadAllPlaceGroups();
    if (existing.isNotEmpty) return null;

    final autoUuid = await insertPlaceGroup(
      PlaceGroup(
        name: 'Automatisch',
        placeType: PlaceType.private,
        isAutoGroup: true,
      ),
    );
    final defUuid = await insertPlaceGroup(
      PlaceGroup(name: 'Standard', placeType: PlaceType.public),
    );
    return (autoGroupUuid: autoUuid, defaultGroupUuid: defUuid);
  }
}
