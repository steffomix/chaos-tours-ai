import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/location_point.dart';
import '../models/saved_place.dart';
import '../models/tour.dart';

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
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE saved_places (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        radius REAL NOT NULL DEFAULT 50.0,
        color_type INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE tours (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        calendar_event_id TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE location_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tour_id INTEGER NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        FOREIGN KEY (tour_id) REFERENCES tours(id) ON DELETE CASCADE
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

  // ── Tours ────────────────────────────────────────────────────────────────

  Future<int> insertTour(Tour tour) async {
    final db = await database;
    return db.insert('tours', tour.toMap());
  }

  Future<List<Tour>> loadAllTours() async {
    final db = await database;
    final rows = await db.query('tours', orderBy: 'start_time DESC');
    return rows.map(Tour.fromMap).toList();
  }

  Future<Tour?> loadActiveTour() async {
    final db = await database;
    final rows = await db.query('tours', where: 'end_time IS NULL', limit: 1);
    if (rows.isEmpty) return null;
    return Tour.fromMap(rows.first);
  }

  Future<void> updateTour(Tour tour) async {
    final db = await database;
    await db.update(
      'tours',
      tour.toMap(),
      where: 'id = ?',
      whereArgs: [tour.id],
    );
  }

  Future<void> deleteTour(int id) async {
    final db = await database;
    await db.delete('tours', where: 'id = ?', whereArgs: [id]);
  }

  // ── LocationPoints ───────────────────────────────────────────────────────

  Future<int> insertLocationPoint(LocationPoint point) async {
    final db = await database;
    return db.insert('location_points', point.toMap());
  }

  Future<List<LocationPoint>> loadPointsForTour(int tourId) async {
    final db = await database;
    final rows = await db.query(
      'location_points',
      where: 'tour_id = ?',
      whereArgs: [tourId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(LocationPoint.fromMap).toList();
  }

  Future<void> deletePointsForTour(int tourId) async {
    final db = await database;
    await db.delete(
      'location_points',
      where: 'tour_id = ?',
      whereArgs: [tourId],
    );
  }
}
