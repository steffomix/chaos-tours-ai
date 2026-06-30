import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import '../models/trusted_source.dart';
import 'sync_service.dart' show SyncOptions;
import 'settings_service.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbFilename = 'chaos_tours.sqlite';

  static const _uuid = Uuid();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _openDatabase();
    _db!.execute('PRAGMA foreign_keys = ON');
    return _db!;
  }

  // No onUpgrade!
  // For the app is still in early development and we can always just delete
  // the old schema and start fresh. This also simplifies development and testing, as we
  // don't have to worry about migrations when changing the schema.
  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbFilename);
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE place_groups (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        place_type INTEGER NOT NULL DEFAULT 0,
        telegram_connection_uuid TEXT,
        calendar_id TEXT,
        name TEXT NOT NULL,
        include_notes INTEGER NOT NULL DEFAULT 1,
        include_persons INTEGER NOT NULL DEFAULT 1,
        include_activities INTEGER NOT NULL DEFAULT 1,
        is_auto_group INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_place_groups_device_id ON place_groups(device_id) WHERE deleted_at IS NULL',
    );

    await db.execute('''
      CREATE TABLE saved_places (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        group_uuid TEXT,
        origin_type INTEGER NOT NULL DEFAULT 0,
        name TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        radius REAL NOT NULL DEFAULT 50.0,
        notes TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0,
        interval_enabled INTEGER NOT NULL DEFAULT 0,
        interval_days INTEGER,
        origin_source_uuid TEXT,
        website TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        experience_rating_average REAL DEFAULT NULL,
        experience_rating_median REAL DEFAULT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        FOREIGN KEY (group_uuid) REFERENCES place_groups(uuid) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_saved_places_lat ON saved_places(lat) WHERE deleted_at IS NULL',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_saved_places_lng ON saved_places(lng) WHERE deleted_at IS NULL',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_saved_places__uuid ON saved_places(device_id, uuid) WHERE deleted_at IS NULL',
    );

    await db.execute('''
      CREATE TABLE stays (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        place_uuid TEXT,
        calendar_event_id TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        notes TEXT NOT NULL DEFAULT '',
        telegram_message_id TEXT,
        address TEXT,
        status TEXT NOT NULL DEFAULT 'detecting',
        is_interval INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        FOREIGN KEY (place_uuid) REFERENCES saved_places(uuid) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stays_status ON stays(status) WHERE deleted_at IS NULL',
    );

    await db.execute('''
      CREATE TABLE persons (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE activities (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE stay_persons (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        stay_uuid TEXT NOT NULL,
        person_uuid TEXT,
        name TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        FOREIGN KEY (stay_uuid) REFERENCES stays(uuid) ON DELETE CASCADE,
        FOREIGN KEY (person_uuid) REFERENCES persons(uuid) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stay_persons_stay_uuid ON stay_persons(stay_uuid) WHERE deleted_at IS NULL',
    );

    await db.execute('''
      CREATE TABLE stay_activities (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        stay_uuid TEXT NOT NULL,
        activity_uuid TEXT,
        description TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        FOREIGN KEY (stay_uuid) REFERENCES stays(uuid) ON DELETE CASCADE,
        FOREIGN KEY (activity_uuid) REFERENCES activities(uuid) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stay_activities_stay_uuid ON stay_activities(stay_uuid) WHERE deleted_at IS NULL',
    );

    await db.execute('''
      CREATE TABLE tracking_points (
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE aktivitaeten (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        name TEXT NOT NULL,
        gps_interval_seconds INTEGER NOT NULL DEFAULT 15,
        stay_detection_seconds INTEGER NOT NULL DEFAULT 180,
        auto_place_seconds INTEGER NOT NULL DEFAULT 900,
        default_radius_meters REAL NOT NULL DEFAULT 50.0,
        auto_create_places INTEGER NOT NULL DEFAULT 1,
        filter_require_experiences INTEGER NOT NULL DEFAULT 0,
        filter_min_avg_rating REAL NOT NULL DEFAULT 0.0,
        filter_distance_enabled INTEGER NOT NULL DEFAULT 0,
        filter_max_distance_km REAL NOT NULL DEFAULT 100.0,
        filter_use_median INTEGER NOT NULL DEFAULT 0,
        filter_use_specific_rating INTEGER NOT NULL DEFAULT 0,
        filter_specific_rating_field TEXT NOT NULL DEFAULT '',
        auto_place_group_uuid TEXT,
        default_place_group_uuid TEXT,
        timeline_history_days INTEGER NOT NULL DEFAULT 7,
        use_osm INTEGER NOT NULL DEFAULT 0,
        search_country TEXT NOT NULL DEFAULT '',
        scheduler_color_range INTEGER NOT NULL DEFAULT 14,
        scheduler_group_ids TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_sources (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        sync_url TEXT NOT NULL DEFAULT '',
        api_key TEXT NOT NULL DEFAULT '',
        info_url TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        sync_options TEXT NOT NULL DEFAULT '{}',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE place_experiences (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        saved_place_uuid TEXT NOT NULL,
        stay_uuid TEXT,
        text TEXT NOT NULL DEFAULT '',
        rating_dangerous_friendly INTEGER NOT NULL DEFAULT 0,
        rating_fraud_reliable INTEGER NOT NULL DEFAULT 0,
        rating_dismissive_accommodation INTEGER NOT NULL DEFAULT 0,
        rating_food INTEGER NOT NULL DEFAULT 0,
        rating_equipment INTEGER NOT NULL DEFAULT 0,
        rating_transport INTEGER NOT NULL DEFAULT 0,
        rating_medicine INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_place_experiences_saved_place_uuid ON place_experiences(saved_place_uuid) WHERE deleted_at IS NULL',
    );

    // Triggers: keep experience_rating_average / _median on saved_places in sync.
    // Average = mean of per-experience overall scores (each score = avg of 6 dims).
    // Median uses SQLite window functions (available since 3.25 / Android API 21+).
    // NULL is stored when the place has no (non-deleted) experiences.
    for (final trigger in [
      // AFTER INSERT
      '''
        CREATE TRIGGER IF NOT EXISTS trg_pe_ratings_insert
        AFTER INSERT ON place_experiences
        BEGIN
          UPDATE saved_places
          SET
            experience_rating_average = (
              SELECT CASE WHEN COUNT(*) = 0 THEN NULL
                ELSE (AVG(rating_dangerous_friendly) + AVG(rating_fraud_reliable) +
                      AVG(rating_dismissive_accommodation) + AVG(rating_food) +
                      AVG(rating_equipment) + AVG(rating_transport) +
                      AVG(rating_medicine)) / 7.0
              END
              FROM place_experiences
              WHERE saved_place_uuid = NEW.saved_place_uuid AND deleted_at IS NULL
            ),
            experience_rating_median = (
              SELECT CASE WHEN COUNT(*) = 0 THEN NULL
                ELSE (
                  SELECT AVG(val) FROM (
                    SELECT val,
                           ROW_NUMBER() OVER (ORDER BY val) AS rn,
                           COUNT(*) OVER () AS cnt
                    FROM (
                      SELECT (rating_dangerous_friendly + rating_fraud_reliable +
                              rating_dismissive_accommodation + rating_food +
                              rating_equipment + rating_transport +
                              rating_medicine) / 7.0 AS val
                      FROM place_experiences
                      WHERE saved_place_uuid = NEW.saved_place_uuid AND deleted_at IS NULL
                    )
                  ) WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
                )
              END
              FROM place_experiences
              WHERE saved_place_uuid = NEW.saved_place_uuid AND deleted_at IS NULL
            )
          WHERE uuid = NEW.saved_place_uuid;
        END
      ''',
      // AFTER UPDATE
      '''
        CREATE TRIGGER IF NOT EXISTS trg_pe_ratings_update
        AFTER UPDATE ON place_experiences
        BEGIN
          UPDATE saved_places
          SET
            experience_rating_average = (
              SELECT CASE WHEN COUNT(*) = 0 THEN NULL
                ELSE (AVG(rating_dangerous_friendly) + AVG(rating_fraud_reliable) +
                      AVG(rating_dismissive_accommodation) + AVG(rating_food) +
                      AVG(rating_equipment) + AVG(rating_transport) +
                      AVG(rating_medicine)) / 7.0
              END
              FROM place_experiences
              WHERE saved_place_uuid = NEW.saved_place_uuid AND deleted_at IS NULL
            ),
            experience_rating_median = (
              SELECT CASE WHEN COUNT(*) = 0 THEN NULL
                ELSE (
                  SELECT AVG(val) FROM (
                    SELECT val,
                           ROW_NUMBER() OVER (ORDER BY val) AS rn,
                           COUNT(*) OVER () AS cnt
                    FROM (
                      SELECT (rating_dangerous_friendly + rating_fraud_reliable +
                              rating_dismissive_accommodation + rating_food +
                              rating_equipment + rating_transport +
                              rating_medicine) / 7.0 AS val
                      FROM place_experiences
                      WHERE saved_place_uuid = NEW.saved_place_uuid AND deleted_at IS NULL
                    )
                  ) WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
                )
              END
              FROM place_experiences
              WHERE saved_place_uuid = NEW.saved_place_uuid AND deleted_at IS NULL
            )
          WHERE uuid = NEW.saved_place_uuid;
        END
      ''',
      // AFTER DELETE
      '''
        CREATE TRIGGER IF NOT EXISTS trg_pe_ratings_delete
        AFTER DELETE ON place_experiences
        BEGIN
          UPDATE saved_places
          SET
            experience_rating_average = (
              SELECT CASE WHEN COUNT(*) = 0 THEN NULL
                ELSE (AVG(rating_dangerous_friendly) + AVG(rating_fraud_reliable) +
                      AVG(rating_dismissive_accommodation) + AVG(rating_food) +
                      AVG(rating_equipment) + AVG(rating_transport) +
                      AVG(rating_medicine)) / 7.0
              END
              FROM place_experiences
              WHERE saved_place_uuid = OLD.saved_place_uuid AND deleted_at IS NULL
            ),
            experience_rating_median = (
              SELECT CASE WHEN COUNT(*) = 0 THEN NULL
                ELSE (
                  SELECT AVG(val) FROM (
                    SELECT val,
                           ROW_NUMBER() OVER (ORDER BY val) AS rn,
                           COUNT(*) OVER () AS cnt
                    FROM (
                      SELECT (rating_dangerous_friendly + rating_fraud_reliable +
                              rating_dismissive_accommodation + rating_food +
                              rating_equipment + rating_transport +
                              rating_medicine) / 7.0 AS val
                      FROM place_experiences
                      WHERE saved_place_uuid = OLD.saved_place_uuid AND deleted_at IS NULL
                    )
                  ) WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
                )
              END
              FROM place_experiences
              WHERE saved_place_uuid = OLD.saved_place_uuid AND deleted_at IS NULL
            )
          WHERE uuid = OLD.saved_place_uuid;
        END
      ''',
    ]) {
      await db.execute(trigger);
    }

    await db.execute('''
      CREATE TABLE sync_source_experiences (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        sync_source_uuid TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_source_experiences_sync_source_uuid ON sync_source_experiences(sync_source_uuid) WHERE deleted_at IS NULL',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS place_photos (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        place_uuid TEXT,
        stay_uuid TEXT,
        caption TEXT NOT NULL DEFAULT '',
        taken_at INTEGER NOT NULL DEFAULT 0,
        photo_data BLOB NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        FOREIGN KEY (place_uuid) REFERENCES saved_places(uuid) ON DELETE CASCADE,
        FOREIGN KEY (stay_uuid) REFERENCES stays(uuid) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_place_photos_place ON place_photos(place_uuid) WHERE deleted_at IS NULL',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_place_photos_stay ON place_photos(stay_uuid) WHERE deleted_at IS NULL',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS telegram_connections (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        bot_token TEXT NOT NULL DEFAULT '',
        chat_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE trusted_sources (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        trusted_device_id TEXT NOT NULL,
        trusted INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        url TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        lat REAL,
        lng REAL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_trusted_sources_trusted_device_id ON trusted_sources(trusted_device_id) WHERE deleted_at IS NULL',
    );

    await db.execute(
      'CREATE UNIQUE INDEX idx_trusted_sources_device_id'
      ' ON trusted_sources(trusted_device_id) WHERE deleted_at IS NULL',
    );
  }

  // ── Database Explorer ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getExplorerTables() async {
    final db = await database;
    return await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'android_metadata' AND name NOT LIKE 'sqlite_sequence'",
    );
  }

  Future<List<Map<String, dynamic>>> getExplorerTableInfo(
    String tableName,
  ) async {
    final db = await database;
    return await db.rawQuery('PRAGMA table_info($tableName)');
  }

  Future<List<Map<String, dynamic>>> getExplorerTableRows(
    String tableName, {
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    return await db.query(tableName, limit: limit, offset: offset);
  }

  Future<int> updateExplorerTableRow(
    String tableName,
    Map<String, dynamic> values,
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    return await db.update(
      tableName,
      values,
      where: whereClause,
      whereArgs: whereArgs,
    );
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
    final effectiveDeviceId = deviceId.isNotEmpty
        ? deviceId
        : ((map['device_id'] as String?)?.isNotEmpty == true
              ? map['device_id'] as String
              : SettingsService.instance.deviceId);
    return {
      ...map,
      'uuid': (map['uuid'] as String?)?.isNotEmpty == true
          ? map['uuid']
          : generateUuid(),
      'updated_at': now,
      'device_id': effectiveDeviceId,
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

  /// Returns all non-deleted places whose coordinates fall within the given
  /// bounding box. Indexes on lat/lng make this significantly faster than a
  /// full-table scan when the dataset is large.
  Future<List<SavedPlace>> loadPlacesWithinBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
  }) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT sp.*,
             COALESCE(pg.place_type, 0) AS place_type
      FROM saved_places sp
      LEFT JOIN place_groups pg ON sp.group_uuid = pg.uuid
      WHERE sp.deleted_at IS NULL
        AND sp.lat BETWEEN ? AND ?
        AND sp.lng BETWEEN ? AND ?
    ''',
      [minLat, maxLat, minLng, maxLng],
    );
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

  Future<SavedPlace?> getSavedPlace(String? placeUuid) async {
    if (placeUuid == null) return null;
    final db = await database;
    final rows = await db.query(
      'saved_places',
      where: 'uuid = ? AND deleted_at IS NULL',
      whereArgs: [placeUuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SavedPlace.fromMap(rows.first);
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

  /// Returns ALL non-completed stays (used for multi-place state restore on init).
  Future<List<Stay>> loadAllActiveStays() async {
    final db = await database;
    final rows = await db.query(
      'stays',
      where: "status != 'completed'",
      orderBy: 'start_time DESC',
    );
    return rows.map(Stay.fromMap).toList();
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
    final map = _withSyncFields(a.toMap(), a.deviceId);
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
      _withSyncFields(a.toMap(), a.deviceId),
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
    return join(dbPath, _dbFilename);
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

  /// Opens [sourcePath] as a separate read-only SQLite database and merges all
  /// rows from every sync table into the local database using last-write-wins
  /// semantics (identical to the server sync pull).
  ///
  /// When [options] is null every table is merged with full insert/update/delete
  /// permissions. Pass a [SyncSourceOptions] to restrict which tables and
  /// operations are applied.
  ///
  /// Returns the total number of rows processed.
  Future<int> syncFromDatabaseFile(
    String sourcePath, {
    SyncSourceOptions? options,
  }) async {
    final sourceDb = await openDatabase(sourcePath, readOnly: true);
    int count = 0;
    try {
      for (final table in SyncSourceOptions.allTables) {
        final tableOpts = options?.forTable(table);
        // If options are specified and nothing is enabled for this table, skip.
        if (tableOpts != null && !tableOpts.anyEnabled) continue;

        final tableCheck = await sourceDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        if (tableCheck.isEmpty) continue;
        final rows = await sourceDb.query(table);
        for (final row in rows) {
          final syncOpts = tableOpts == null
              ? SyncOptions.all
              : SyncOptions(
                  allowInsert: tableOpts.insert,
                  allowEdit: tableOpts.update,
                  allowDelete: tableOpts.delete,
                );
          await upsertByUuid(
            table,
            Map<String, dynamic>.from(row),
            options: syncOpts,
          );
          count++;
        }
      }
    } finally {
      await sourceDb.close();
    }
    return count;
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

  /// Returns a map from place UUID to cached average rating.
  /// Uses the pre-computed [experience_rating_average] column.
  Future<Map<String, double>> loadAverageRatingsForAllPlaces() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT uuid, experience_rating_average
      FROM saved_places
      WHERE deleted_at IS NULL AND experience_rating_average IS NOT NULL
    ''');
    return {
      for (final r in rows)
        r['uuid'] as String: (r['experience_rating_average'] as num).toDouble(),
    };
  }

  /// Recalculates [experience_rating_average] and [experience_rating_median]
  /// for ALL places. Call this after bulk imports where triggers may not have
  /// fired (e.g. [importDump]).
  Future<void> recalculateAllPlaceRatings() async {
    final db = await database;
    // Average
    await db.rawUpdate('''
      UPDATE saved_places
      SET experience_rating_average = (
        SELECT CASE WHEN COUNT(*) = 0 THEN NULL
          ELSE (AVG(rating_dangerous_friendly) + AVG(rating_fraud_reliable) +
                AVG(rating_dismissive_accommodation) + AVG(rating_food) +
                AVG(rating_equipment) + AVG(rating_transport) +
                AVG(rating_medicine)) / 7.0
        END
        FROM place_experiences
        WHERE saved_place_uuid = saved_places.uuid AND deleted_at IS NULL
      )
    ''');
    // Median — per-place subquery using window functions
    final uuids = await db.rawQuery(
      'SELECT uuid FROM saved_places WHERE deleted_at IS NULL',
    );
    for (final row in uuids) {
      final uuid = row['uuid'] as String;
      await db.rawUpdate(
        '''
        UPDATE saved_places
        SET experience_rating_median = (
          SELECT CASE WHEN COUNT(*) = 0 THEN NULL
            ELSE (
              SELECT AVG(val) FROM (
                SELECT val,
                       ROW_NUMBER() OVER (ORDER BY val) AS rn,
                       COUNT(*) OVER () AS cnt
                FROM (
                  SELECT (rating_dangerous_friendly + rating_fraud_reliable +
                          rating_dismissive_accommodation + rating_food +
                          rating_equipment + rating_transport +
                          rating_medicine) / 7.0 AS val
                  FROM place_experiences
                  WHERE saved_place_uuid = ? AND deleted_at IS NULL
                )
              ) WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
            )
          END
          FROM place_experiences
          WHERE saved_place_uuid = ? AND deleted_at IS NULL
        )
        WHERE uuid = ?
      ''',
        [uuid, uuid, uuid],
      );
    }
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
        AVG(rating_transport) AS r6,
        AVG(rating_medicine) AS r7
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
      'medicine': ((r['r7'] as num?) ?? 0).toDouble(),
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
    final rows = await db.query(
      table,
      where: 'updated_at > ?',
      whereArgs: [since],
    );
    if (table != 'place_photos') return rows;
    // Encode BLOB photo_data to base64 string for JSON transport.
    return rows.map((row) {
      final data = row['photo_data'];
      if (data is List<int>) {
        final copy = Map<String, dynamic>.from(row);
        copy['photo_data'] = base64Encode(Uint8List.fromList(data));
        return copy;
      }
      return row;
    }).toList();
  }

  Future<void> upsertByUuid(
    String table,
    Map<String, dynamic> row, {
    SyncOptions options = SyncOptions.all,
  }) async {
    // Decode base64 photo_data from JSON sync back to BLOB bytes.
    Map<String, dynamic> localRow = row;
    if (table == 'place_photos') {
      final data = row['photo_data'];
      if (data is String && data.isNotEmpty) {
        localRow = Map<String, dynamic>.from(row);
        try {
          localRow['photo_data'] = base64Decode(data);
        } catch (_) {}
      }
    }
    final db = await database;
    final uuid = localRow['uuid'] as String?;
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
        Map<String, dynamic>.from(localRow),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      final localUpdatedAt = (existing.first['updated_at'] as int?) ?? 0;
      final remoteUpdatedAt = (localRow['updated_at'] as int?) ?? 0;
      if (remoteUpdatedAt > localUpdatedAt) {
        final isDelete =
            localRow['deleted_at'] != null &&
            existing.first['deleted_at'] == null;
        if (isDelete && !options.allowDelete) return;
        if (!isDelete && !options.allowEdit) return;
        await db.update(
          table,
          Map<String, dynamic>.from(localRow),
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
    final uuid = await insertAktivitaet(
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
    return uuid;
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

  // ── Paginated queries ────────────────────────────────────────────────────

  /// Loads a page of non-deleted places for the list view with all filters
  /// applied at the SQL level.
  /// [placeTypeIndices] filters by [PlaceType.index] values (top-level AND
  /// filter, independent of [search]).
  /// Set [useMedian] to filter by [experience_rating_median] instead of
  /// [experience_rating_average].
  /// Set [specificRatingField] (a DB column name like 'rating_dangerous_friendly')
  /// to filter and sort by that specific dimension's average/median instead of
  /// the overall cached rating.
  Future<List<SavedPlace>> loadPlacesPaged({
    required int limit,
    required int offset,
    String? search,
    bool intervalOnly = false,
    List<String> groupFilter = const [],
    List<String> placeDeviceIds = const [],
    bool requireExperiences = false,
    List<String> experienceDeviceIds = const [],
    double? minAvgRating,
    bool useMedian = false,
    List<int> placeTypeIndices = const [],
    String? specificRatingField,
  }) async {
    final db = await database;
    final where = <String>['sp.deleted_at IS NULL'];
    final args = <dynamic>[];

    if (intervalOnly) where.add('sp.interval_enabled = 1');

    if (groupFilter.isNotEmpty) {
      final ph = groupFilter.map((_) => '?').join(',');
      where.add('sp.group_uuid IN ($ph)');
      args.addAll(groupFilter);
    }

    if (placeDeviceIds.isNotEmpty) {
      final ph = placeDeviceIds.map((_) => '?').join(',');
      where.add('sp.device_id IN ($ph)');
      args.addAll(placeDeviceIds);
    }

    // Top-level place-type filter (independent of search).
    if (placeTypeIndices.isNotEmpty) {
      final ph = placeTypeIndices.map((_) => '?').join(',');
      where.add('COALESCE(pg.place_type, 0) IN ($ph)');
      args.addAll(placeTypeIndices);
    }

    if (search != null && search.isNotEmpty) {
      final s = '%$search%';
      where.add('''
        (
          sp.name LIKE ?
          OR sp.notes LIKE ?
          OR sp.website LIKE ?
          OR sp.email LIKE ?
          OR sp.phone LIKE ?
          OR EXISTS (
            SELECT 1 FROM place_experiences pe
            WHERE pe.saved_place_uuid = sp.uuid
              AND pe.deleted_at IS NULL
              AND pe.text LIKE ?
          )
          OR EXISTS (
            SELECT 1 FROM stays st
            LEFT JOIN stay_persons spn ON spn.stay_uuid = st.uuid AND spn.deleted_at IS NULL
            LEFT JOIN stay_activities sa ON sa.stay_uuid = st.uuid AND sa.deleted_at IS NULL
            WHERE st.place_uuid = sp.uuid
              AND st.deleted_at IS NULL
              AND (
                st.notes LIKE ?
                OR st.address LIKE ?
                OR spn.name LIKE ?
                OR sa.description LIKE ?
              )
          )
        )
      ''');
      args.addAll([s, s, s, s, s, s, s, s, s, s]);
    }

    // Build the ORDER BY clause (and optional filter subquery for specific mode).
    String orderBy = 'sp.name ASC';

    if (experienceDeviceIds.isNotEmpty) {
      final ph = experienceDeviceIds.map((_) => '?').join(',');
      where.add(
        'EXISTS (SELECT 1 FROM place_experiences'
        ' WHERE saved_place_uuid = sp.uuid'
        ' AND deleted_at IS NULL AND device_id IN ($ph))',
      );
      args.addAll(experienceDeviceIds);
    }

    if (specificRatingField != null &&
        specificRatingField.isNotEmpty &&
        requireExperiences) {
      // Specific dimension filter: require non-NULL AVG for the chosen field.
      final dimAvgSubq =
          '(SELECT AVG($specificRatingField) FROM place_experiences'
          ' WHERE saved_place_uuid = sp.uuid AND deleted_at IS NULL)';
      final dimMedianSubq =
          '(SELECT AVG(val) FROM ('
          'SELECT val, ROW_NUMBER() OVER (ORDER BY val) AS rn,'
          ' COUNT(*) OVER () AS cnt'
          ' FROM (SELECT $specificRatingField AS val FROM place_experiences'
          ' WHERE saved_place_uuid = sp.uuid AND deleted_at IS NULL)'
          ') WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2))';
      final dimSubq = useMedian ? dimMedianSubq : dimAvgSubq;

      if (minAvgRating != null) {
        where.add('($dimSubq IS NOT NULL AND $dimSubq >= ?)');
        args.add(minAvgRating);
      } else {
        where.add('$dimSubq IS NOT NULL');
      }
      // Sort by the chosen dimension descending (nulls last via COALESCE).
      orderBy = 'COALESCE($dimAvgSubq, -999) DESC, sp.name ASC';
    } else if (requireExperiences) {
      // Must have at least one experience (cached column is non-NULL)
      final col = useMedian
          ? 'sp.experience_rating_median'
          : 'sp.experience_rating_average';
      if (minAvgRating != null) {
        where.add('($col IS NOT NULL AND $col >= ?)');
        args.add(minAvgRating);
      } else {
        where.add('$col IS NOT NULL');
      }
    } else if (minAvgRating != null) {
      final col = useMedian
          ? 'sp.experience_rating_median'
          : 'sp.experience_rating_average';
      // Places without experiences (NULL) always pass the rating filter
      where.add('COALESCE($col, 999) >= ?');
      args.add(minAvgRating);
    }

    args.addAll([limit, offset]);
    final rows = await db.rawQuery('''
      SELECT sp.*, COALESCE(pg.place_type, 0) AS place_type
      FROM saved_places sp
      LEFT JOIN place_groups pg ON sp.group_uuid = pg.uuid
      WHERE ${where.join(' AND ')}
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
    ''', args);
    return rows.map(SavedPlace.fromMap).toList();
  }

  /// Returns the total count matching the same filters as [loadPlacesPaged].
  Future<int> countPlaces({
    String? search,
    bool intervalOnly = false,
    List<String> groupFilter = const [],
    List<String> placeDeviceIds = const [],
    bool requireExperiences = false,
    List<String> experienceDeviceIds = const [],
    double? minAvgRating,
    bool useMedian = false,
    List<int> placeTypeIndices = const [],
    String? specificRatingField,
  }) async {
    final db = await database;
    final where = <String>['sp.deleted_at IS NULL'];
    final args = <dynamic>[];

    if (intervalOnly) where.add('sp.interval_enabled = 1');

    if (groupFilter.isNotEmpty) {
      final ph = groupFilter.map((_) => '?').join(',');
      where.add('sp.group_uuid IN ($ph)');
      args.addAll(groupFilter);
    }

    if (placeDeviceIds.isNotEmpty) {
      final ph = placeDeviceIds.map((_) => '?').join(',');
      where.add('sp.device_id IN ($ph)');
      args.addAll(placeDeviceIds);
    }

    // Top-level place-type filter (independent of search).
    if (placeTypeIndices.isNotEmpty) {
      final ph = placeTypeIndices.map((_) => '?').join(',');
      where.add('COALESCE(pg.place_type, 0) IN ($ph)');
      args.addAll(placeTypeIndices);
    }

    if (search != null && search.isNotEmpty) {
      final s = '%$search%';
      where.add('''
        (
          sp.name LIKE ?
          OR sp.notes LIKE ?
          OR sp.website LIKE ?
          OR sp.email LIKE ?
          OR sp.phone LIKE ?
          OR EXISTS (
            SELECT 1 FROM place_experiences pe
            WHERE pe.saved_place_uuid = sp.uuid
              AND pe.deleted_at IS NULL
              AND pe.text LIKE ?
          )
          OR EXISTS (
            SELECT 1 FROM stays st
            LEFT JOIN stay_persons spn ON spn.stay_uuid = st.uuid AND spn.deleted_at IS NULL
            LEFT JOIN stay_activities sa ON sa.stay_uuid = st.uuid AND sa.deleted_at IS NULL
            WHERE st.place_uuid = sp.uuid
              AND st.deleted_at IS NULL
              AND (
                st.notes LIKE ?
                OR st.address LIKE ?
                OR spn.name LIKE ?
                OR sa.description LIKE ?
              )
          )
        )
      ''');
      args.addAll([s, s, s, s, s, s, s, s, s, s]);
    }

    if (experienceDeviceIds.isNotEmpty) {
      final ph = experienceDeviceIds.map((_) => '?').join(',');
      where.add(
        'EXISTS (SELECT 1 FROM place_experiences'
        ' WHERE saved_place_uuid = sp.uuid'
        ' AND deleted_at IS NULL AND device_id IN ($ph))',
      );
      args.addAll(experienceDeviceIds);
    }

    if (specificRatingField != null &&
        specificRatingField.isNotEmpty &&
        requireExperiences) {
      final dimAvgSubq =
          '(SELECT AVG($specificRatingField) FROM place_experiences'
          ' WHERE saved_place_uuid = sp.uuid AND deleted_at IS NULL)';
      if (minAvgRating != null) {
        where.add('($dimAvgSubq IS NOT NULL AND $dimAvgSubq >= ?)');
        args.add(minAvgRating);
      } else {
        where.add('$dimAvgSubq IS NOT NULL');
      }
    } else if (requireExperiences) {
      final col = useMedian
          ? 'sp.experience_rating_median'
          : 'sp.experience_rating_average';
      if (minAvgRating != null) {
        where.add('($col IS NOT NULL AND $col >= ?)');
        args.add(minAvgRating);
      } else {
        where.add('$col IS NOT NULL');
      }
    } else if (minAvgRating != null) {
      final col = useMedian
          ? 'sp.experience_rating_median'
          : 'sp.experience_rating_average';
      where.add('COALESCE($col, 999) >= ?');
      args.add(minAvgRating);
    }

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS cnt
      FROM saved_places sp
      LEFT JOIN place_groups pg ON sp.group_uuid = pg.uuid
      WHERE ${where.join(' AND ')}
    ''', args);
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Loads a page of completed stays with all filters applied at the SQL level.
  /// When [search] is set, the query joins stay_persons and stay_activities and
  /// uses DISTINCT to avoid duplicate rows.
  Future<List<Stay>> loadCompletedStaysPaged({
    required int limit,
    required int offset,
    String? search,
    int? fromMs,
    int? toMs,
    String? placeUuid,
    String? deviceId,
  }) async {
    final db = await database;
    final where = <String>["s.status = 'completed'"];
    final args = <dynamic>[];

    if (fromMs != null) {
      where.add('s.start_time >= ?');
      args.add(fromMs);
    }
    if (toMs != null) {
      where.add('s.start_time <= ?');
      args.add(toMs);
    }
    if (placeUuid != null) {
      where.add('s.place_uuid = ?');
      args.add(placeUuid);
    }
    if (deviceId != null) {
      where.add('s.device_id = ?');
      args.add(deviceId);
    }

    String joins = '';
    if (search != null && search.isNotEmpty) {
      final s = '%$search%';
      joins = '''
        LEFT JOIN saved_places sp ON s.place_uuid = sp.uuid
        LEFT JOIN stay_persons spn ON s.uuid = spn.stay_uuid AND spn.deleted_at IS NULL
        LEFT JOIN stay_activities sa ON s.uuid = sa.stay_uuid AND sa.deleted_at IS NULL
      ''';
      where.add(
        '(sp.name LIKE ? OR s.address LIKE ? OR s.notes LIKE ? OR spn.name LIKE ? OR sa.description LIKE ?)',
      );
      args.addAll([s, s, s, s, s]);
    }

    args.addAll([limit, offset]);
    final rows = await db.rawQuery('''
      SELECT DISTINCT s.*
      FROM stays s
      $joins
      WHERE ${where.join(' AND ')}
      ORDER BY s.start_time DESC
      LIMIT ? OFFSET ?
    ''', args);
    return rows.map(Stay.fromMap).toList();
  }

  /// Returns the total count matching the same filters as [loadCompletedStaysPaged].
  Future<int> countCompletedStays({
    String? search,
    int? fromMs,
    int? toMs,
    String? placeUuid,
  }) async {
    final db = await database;
    final where = <String>["s.status = 'completed'"];
    final args = <dynamic>[];

    if (fromMs != null) {
      where.add('s.start_time >= ?');
      args.add(fromMs);
    }
    if (toMs != null) {
      where.add('s.start_time <= ?');
      args.add(toMs);
    }
    if (placeUuid != null) {
      where.add('s.place_uuid = ?');
      args.add(placeUuid);
    }

    String joins = '';
    if (search != null && search.isNotEmpty) {
      final s = '%$search%';
      joins = '''
        LEFT JOIN saved_places sp ON s.place_uuid = sp.uuid
        LEFT JOIN stay_persons spn ON s.uuid = spn.stay_uuid AND spn.deleted_at IS NULL
        LEFT JOIN stay_activities sa ON s.uuid = sa.stay_uuid AND sa.deleted_at IS NULL
      ''';
      where.add(
        '(sp.name LIKE ? OR s.address LIKE ? OR s.notes LIKE ? OR spn.name LIKE ? OR sa.description LIKE ?)',
      );
      args.addAll([s, s, s, s, s]);
    }

    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT s.uuid) AS cnt
      FROM stays s
      $joins
      WHERE ${where.join(' AND ')}
    ''', args);
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Loads a page of interval-enabled places for the scheduler, sorted by
  /// urgency (days_remaining ASC) computed entirely in SQL.
  Future<List<({SavedPlace place, int daysRemaining})>>
  loadSchedulerPlacesPaged({
    required int limit,
    required int offset,
    List<String> groupFilter = const [],
  }) async {
    final db = await database;
    final where = <String>['sp.deleted_at IS NULL', 'sp.interval_enabled = 1'];
    final args = <dynamic>[];

    if (groupFilter.isNotEmpty) {
      final ph = groupFilter.map((_) => '?').join(',');
      where.add('sp.group_uuid IN ($ph)');
      args.addAll(groupFilter);
    }

    args.addAll([limit, offset]);
    final rows = await db.rawQuery('''
      SELECT sp.*,
             COALESCE(pg.place_type, 0) AS place_type,
             CASE
               WHEN lv.last_visit_ms IS NULL THEN 0
               ELSE COALESCE(sp.interval_days, 0)
                    - CAST((unixepoch('now') * 1000 - lv.last_visit_ms) / 86400000 AS INTEGER)
             END AS days_remaining_val
      FROM saved_places sp
      LEFT JOIN place_groups pg ON sp.group_uuid = pg.uuid
      LEFT JOIN (
        SELECT place_uuid, MAX(start_time) AS last_visit_ms
        FROM stays
        WHERE status = 'completed' AND is_interval = 1
        GROUP BY place_uuid
      ) lv ON lv.place_uuid = sp.uuid
      WHERE ${where.join(' AND ')}
      ORDER BY days_remaining_val ASC
      LIMIT ? OFFSET ?
    ''', args);

    return rows.map((r) {
      final place = SavedPlace.fromMap(r);
      final days = (r['days_remaining_val'] as int?) ?? 0;
      return (place: place, daysRemaining: days);
    }).toList();
  }

  /// Returns the total count of interval-enabled places matching [groupFilter].
  Future<int> countSchedulerPlaces({
    List<String> groupFilter = const [],
  }) async {
    final db = await database;
    final where = <String>['sp.deleted_at IS NULL', 'sp.interval_enabled = 1'];
    final args = <dynamic>[];

    if (groupFilter.isNotEmpty) {
      final ph = groupFilter.map((_) => '?').join(',');
      where.add('sp.group_uuid IN ($ph)');
      args.addAll(groupFilter);
    }

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS cnt
      FROM saved_places sp
      WHERE ${where.join(' AND ')}
    ''', args);
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Returns distinct photo groups (effective place UUID + photo count + place
  /// name), sorted alphabetically by place name. The null group contains photos
  /// not linked to any place.
  Future<List<({String? placeUuid, int photoCount, String? placeName})>>
  loadPhotoGroupsPaged({required int limit, required int offset}) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT sub.eff_uuid, COUNT(*) AS photo_count, sp.name AS place_name
      FROM (
        SELECT COALESCE(pp.place_uuid, s.place_uuid) AS eff_uuid, pp.uuid AS photo_uuid
        FROM place_photos pp
        LEFT JOIN stays s ON pp.stay_uuid = s.uuid AND s.deleted_at IS NULL
        WHERE pp.deleted_at IS NULL
      ) sub
      LEFT JOIN saved_places sp ON sub.eff_uuid = sp.uuid
      GROUP BY sub.eff_uuid
      ORDER BY CASE WHEN sp.name IS NULL THEN 1 ELSE 0 END, sp.name ASC
      LIMIT ? OFFSET ?
    ''',
      [limit, offset],
    );
    return rows.map((r) {
      return (
        placeUuid: r['eff_uuid'] as String?,
        photoCount: (r['photo_count'] as int?) ?? 0,
        placeName: r['place_name'] as String?,
      );
    }).toList();
  }

  /// Returns the total number of distinct photo groups.
  Future<int> countPhotoGroups() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS cnt FROM (
        SELECT COALESCE(pp.place_uuid, s.place_uuid) AS eff_uuid
        FROM place_photos pp
        LEFT JOIN stays s ON pp.stay_uuid = s.uuid AND s.deleted_at IS NULL
        WHERE pp.deleted_at IS NULL
        GROUP BY eff_uuid
      )
    ''');
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// All non-deleted photos whose effective place matches [placeUuid].
  /// Pass null to get photos not linked to any place.
  Future<List<PlacePhoto>> loadPhotosForEffectivePlace(
    String? placeUuid,
  ) async {
    final db = await database;
    if (placeUuid != null) {
      final rows = await db.rawQuery(
        '''
        SELECT pp.* FROM place_photos pp
        LEFT JOIN stays s ON pp.stay_uuid = s.uuid AND s.deleted_at IS NULL
        WHERE pp.deleted_at IS NULL
          AND COALESCE(pp.place_uuid, s.place_uuid) = ?
        ORDER BY pp.taken_at DESC
      ''',
        [placeUuid],
      );
      return rows.map(PlacePhoto.fromMap).toList();
    } else {
      final rows = await db.rawQuery('''
        SELECT pp.* FROM place_photos pp
        LEFT JOIN stays s ON pp.stay_uuid = s.uuid AND s.deleted_at IS NULL
        WHERE pp.deleted_at IS NULL
          AND pp.place_uuid IS NULL
          AND (pp.stay_uuid IS NULL OR s.place_uuid IS NULL)
        ORDER BY pp.taken_at DESC
      ''');
      return rows.map(PlacePhoto.fromMap).toList();
    }
  }

  // ── TrustedSources ───────────────────────────────────────────────────────

  /// Returns all non-deleted sources — trusted entries first, then the rest,
  /// both groups sorted by [trusted_device_id].
  Future<List<TrustedSource>> loadAllTrustedSources() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM trusted_sources WHERE deleted_at IS NULL'
      ' ORDER BY trusted DESC, trusted_device_id ASC',
    );
    return rows.map(TrustedSource.fromMap).toList();
  }

  Future<void> upsertTrustedSource(TrustedSource ts) async {
    final db = await database;
    await db.insert(
      'trusted_sources',
      ts.toMap()..['updated_at'] = DateTime.now().millisecondsSinceEpoch,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> softDeleteTrustedSource(String uuid) async {
    final db = await database;
    await db.update(
      'trusted_sources',
      {
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Collects all distinct non-empty device IDs from every table and inserts
  /// new entries into [trusted_sources] (existing entries are not modified).
  /// Returns the count of newly discovered device IDs.
  Future<int> refreshTrustedSources() async {
    final db = await database;
    const tables = [
      'saved_places',
      'stays',
      'stay_persons',
      'stay_activities',
      'place_experiences',
      'place_groups',
      'persons',
      'activities',
      'aktivitaeten',
      'sync_sources',
      'sync_source_experiences',
      'place_photos',
      'telegram_connections',
    ];

    // Gather all distinct device IDs from all tables.
    final allIds = <String>{};
    for (final table in tables) {
      try {
        final rows = await db.rawQuery(
          'SELECT DISTINCT device_id FROM $table'
          ' WHERE device_id IS NOT NULL AND device_id != \'\'',
        );
        for (final r in rows) {
          allIds.add(r['device_id'] as String);
        }
      } catch (_) {
        // table may not exist (e.g. during first run)
      }
    }

    // Normalize: old DB records may carry the raw UUID before the user set a
    // device name. Replace any occurrence of the raw UUID with the current
    // full device ID (e.g. "Alice@<uuid>") so we never get two entries for the
    // same physical device.
    final fullDeviceId = SettingsService.instance.deviceId;
    final atIdx = fullDeviceId.lastIndexOf('@');
    final rawUuid = atIdx >= 0
        ? fullDeviceId.substring(atIdx + 1)
        : fullDeviceId;
    if (rawUuid != fullDeviceId) {
      // There is a name prefix — normalise the set.
      allIds.remove(rawUuid);
    }
    allIds.add(fullDeviceId);

    final now = DateTime.now().millisecondsSinceEpoch;

    // If an existing trusted-source entry still holds the raw UUID, rename it.
    if (rawUuid != fullDeviceId) {
      await db.update(
        'trusted_sources',
        {'trusted_device_id': fullDeviceId, 'updated_at': now},
        where: 'trusted_device_id = ? AND deleted_at IS NULL',
        whereArgs: [rawUuid],
      );
    }

    // Load existing entries (after the potential rename above).
    final existing = await loadAllTrustedSources();
    final existingIds = existing.map((t) => t.deviceId).toSet();

    int added = 0;
    for (final id in allIds) {
      if (existingIds.contains(id)) continue;
      await db.insert('trusted_sources', {
        'uuid': _uuid.v4(),
        'trusted_device_id': id,
        'trusted': 0,
        'note': '',
        'url': '',
        'email': '',
        'address': '',
        'updated_at': now,
        'device_id': fullDeviceId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      added++;
    }
    return added;
  }

  /// Returns device IDs of all non-deleted [TrustedSource] entries where
  /// [trusted] is true.
  Future<List<String>> loadTrustedDeviceIds() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT trusted_device_id FROM trusted_sources'
      ' WHERE deleted_at IS NULL AND trusted = 1',
    );
    return rows.map((r) => r['trusted_device_id'] as String).toList();
  }
}
