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
        auto_place_group_id INTEGER
      )
    ''');
  }

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
