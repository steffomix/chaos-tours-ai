import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/aktivitaet.dart';
import '../models/activity.dart';
import '../models/person.dart';
import '../models/place_group.dart';
import '../models/saved_place.dart';
import '../models/stay.dart';
import '../models/stay_activity.dart';
import '../models/stay_person.dart';
import '../models/tracking_log_entry.dart';
import '../models/tracking_point.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

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
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE saved_places (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        radius REAL NOT NULL DEFAULT 50.0,
        place_type INTEGER NOT NULL DEFAULT 1,
        notes TEXT NOT NULL DEFAULT '',
        group_id INTEGER,
        created_at INTEGER NOT NULL DEFAULT 0
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
        is_auto_group INTEGER NOT NULL DEFAULT 0
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
        FOREIGN KEY (place_id) REFERENCES saved_places(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE stay_persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stay_id INTEGER NOT NULL,
        person_id INTEGER,
        name TEXT NOT NULL,
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
        auto_place_place_type INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE tracking_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts INTEGER NOT NULL,
        prev_status TEXT NOT NULL,
        new_status TEXT NOT NULL,
        short_pts INTEGER NOT NULL DEFAULT 0,
        short_full INTEGER NOT NULL DEFAULT 0,
        short_cluster INTEGER NOT NULL DEFAULT 0,
        long_pts INTEGER NOT NULL DEFAULT 0,
        long_full INTEGER NOT NULL DEFAULT 0,
        long_cluster INTEGER NOT NULL DEFAULT 0,
        place_id INTEGER,
        action TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  // ── SavedPlaces ──────────────────────────────────────────────────────────

  Future<int> insertPlace(SavedPlace place) async {
    final db = await database;
    return db.insert('saved_places', place.toMap());
  }

  Future<List<SavedPlace>> loadAllPlaces() async {
    final db = await database;
    final rows = await db.query('saved_places');
    return rows.map(SavedPlace.fromMap).toList();
  }

  Future<void> updatePlace(SavedPlace place) async {
    final db = await database;
    await db.update(
      'saved_places',
      place.toMap(),
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

  /// Returns the start_time of the most recent completed stay at [placeId], or null.
  Future<int?> lastVisitedAtForPlace(int placeId) async {
    final db = await database;
    final rows = await db.query(
      'stays',
      columns: ['start_time'],
      where: "place_id = ? AND status = 'completed'",
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

  // ── Tracking Log ─────────────────────────────────────────────────────────

  Future<void> insertTrackingLog(TrackingLogEntry entry) async {
    final db = await database;
    await db.insert('tracking_log', entry.toMap());
  }

  /// Returns the most recent [limit] log entries (newest first).
  Future<List<TrackingLogEntry>> loadRecentTrackingLog({
    int limit = 500,
  }) async {
    final db = await database;
    final rows = await db.query(
      'tracking_log',
      orderBy: 'ts DESC',
      limit: limit,
    );
    return rows.map(TrackingLogEntry.fromMap).toList();
  }

  /// Deletes log entries older than [hours] hours.
  Future<void> pruneTrackingLog({int hours = 24}) async {
    final db = await database;
    final cutoff = DateTime.now()
        .subtract(Duration(hours: hours))
        .millisecondsSinceEpoch;
    await db.delete('tracking_log', where: 'ts < ?', whereArgs: [cutoff]);
  }

  Future<void> clearTrackingLog() async {
    final db = await database;
    await db.delete('tracking_log');
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

  /// Ensures at least one Aktivitaet exists. Creates a default one if the
  /// table is empty and returns its id.
  Future<int> ensureDefaultAktivitaet({
    int gpsInterval = 15,
    int stayDetection = 180,
    int autoPlace = 900,
    double radius = 50.0,
    bool autoCreate = true,
    int? autoPlaceGroupId,
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
      ),
    );
  }
}
