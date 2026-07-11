"""
SQLite database setup for Chaos Tours sync server.

The schema is intentionally identical to the Flutter app (chaos_tours.sqlite) so that
a database file can be copied freely between app and server without any conversion.
Database file: ./database/chaos_tours.sqlite
"""
import re
from contextlib import asynccontextmanager
from pathlib import Path

import aiosqlite

# ---------------------------------------------------------------------------
# Path
# ---------------------------------------------------------------------------

_SCRIPT_DIR = Path(__file__).parent
DB_DIR = _SCRIPT_DIR / "database"
DB_PATH = DB_DIR / "chaos_tours.sqlite"


def _ensure_db_dir() -> None:
    DB_DIR.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------------------
# Column-name safety (used by sync.py to guard against injection)
# ---------------------------------------------------------------------------

_SAFE_IDENTIFIER = re.compile(r"^[a-z_][a-z0-9_]*$")


def assert_safe_identifier(name: str) -> str:
    """Raise ValueError if *name* is not a safe SQL identifier."""
    if not _SAFE_IDENTIFIER.match(name):
        raise ValueError(f"Unsafe SQL identifier rejected: {name!r}")
    return name


# ---------------------------------------------------------------------------
# Tables that participate in sync (ordered by FK dependency, parents first)
# ---------------------------------------------------------------------------

SYNC_TABLES: list[str] = [
    "place_groups",
    "saved_places",
    "persons",
    "activities",
    "stays",
    "stay_persons",
    "stay_activities",
    "virtual_devices",
    "sync_sources",
    "place_experiences",
    "sync_source_experiences",
    "place_photos",
    "telegram_connections",
    "p2p_messages",
    "message_attachments",
]


# ---------------------------------------------------------------------------
# Connection context manager
# ---------------------------------------------------------------------------

@asynccontextmanager
async def connect():
    """Yield an aiosqlite connection with WAL mode and foreign keys enabled."""
    _ensure_db_dir()
    async with aiosqlite.connect(DB_PATH) as conn:
        conn.row_factory = aiosqlite.Row
        await conn.execute("PRAGMA journal_mode=WAL")
#        await conn.execute("PRAGMA foreign_keys=ON")
        yield conn


# ---------------------------------------------------------------------------
# Schema – kept intentionally identical to the Flutter app's _onCreate so
# that a chaos_tours.sqlite from any device can be dropped in here directly.
# ---------------------------------------------------------------------------

_DDL: list[str] = [
    """
    CREATE TABLE IF NOT EXISTS place_groups (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        place_type INTEGER NOT NULL DEFAULT 0,
        telegram_connection_uuid TEXT,
        name TEXT NOT NULL,
        include_notes INTEGER NOT NULL DEFAULT 1,
        include_persons INTEGER NOT NULL DEFAULT 1,
        include_activities INTEGER NOT NULL DEFAULT 1,
        is_auto_group INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_place_groups_device_id ON place_groups(device_id) WHERE deleted_at IS NULL",

    """
    CREATE TABLE IF NOT EXISTS saved_places (
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
        last_messages_sync_ms INTEGER NOT NULL DEFAULT 0,
        sync_sources_uuid TEXT,
        sync_url TEXT NOT NULL DEFAULT '',
        sync_port INTEGER NOT NULL DEFAULT 8000,
        sync_source_api_key TEXT NOT NULL DEFAULT '',
        sync_source_interval INTEGER NOT NULL DEFAULT 1,
        sync_source_last_sync_ms INTEGER NOT NULL DEFAULT 0,
        sync_source_options TEXT,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        FOREIGN KEY (group_uuid) REFERENCES place_groups(uuid) ON DELETE SET NULL
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_saved_places_lat ON saved_places(lat) WHERE deleted_at IS NULL",
    "CREATE INDEX IF NOT EXISTS idx_saved_places_lng ON saved_places(lng) WHERE deleted_at IS NULL",
    "CREATE INDEX IF NOT EXISTS idx_saved_places__uuid ON saved_places(device_id, uuid) WHERE deleted_at IS NULL",

    """
    CREATE TABLE IF NOT EXISTS stays (
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
    """,
    "CREATE INDEX IF NOT EXISTS idx_stays_status ON stays(status) WHERE deleted_at IS NULL",

    """
    CREATE TABLE IF NOT EXISTS persons (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
    )
    """,

    """
    CREATE TABLE IF NOT EXISTS activities (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
    )
    """,

    """
    CREATE TABLE IF NOT EXISTS stay_persons (
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
    """,
    "CREATE INDEX IF NOT EXISTS idx_stay_persons_stay_uuid ON stay_persons(stay_uuid) WHERE deleted_at IS NULL",

    """
    CREATE TABLE IF NOT EXISTS stay_activities (
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
    """,
    "CREATE INDEX IF NOT EXISTS idx_stay_activities_stay_uuid ON stay_activities(stay_uuid) WHERE deleted_at IS NULL",

    # Not synced, but present for full schema compatibility.
    """
    CREATE TABLE IF NOT EXISTS tracking_points (
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        timestamp INTEGER NOT NULL
    )
    """,

    """
    CREATE TABLE IF NOT EXISTS virtual_devices (
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
        sync_source_place_group_uuid TEXT,
        timeline_history_days INTEGER NOT NULL DEFAULT 7,
        use_osm INTEGER NOT NULL DEFAULT 0,
        search_country TEXT NOT NULL DEFAULT '',
        address_on_auto_create INTEGER NOT NULL DEFAULT 1,
        address_on_manual_create INTEGER NOT NULL DEFAULT 1,
        address_on_interval INTEGER NOT NULL DEFAULT 0,
        scheduler_color_range INTEGER NOT NULL DEFAULT 14,
        scheduler_group_ids TEXT NOT NULL DEFAULT '',
        sync_export_protected INTEGER NOT NULL DEFAULT 0,
        sync_import_protected INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
    )
    """,

    """
    CREATE TABLE IF NOT EXISTS sync_sources (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        sync_url TEXT NOT NULL DEFAULT '',
        sync_port INTEGER NOT NULL DEFAULT 8000,
        api_key TEXT NOT NULL DEFAULT '',
        info_url TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        sync_options TEXT NOT NULL DEFAULT '{}',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
    )
    """,

    """
    CREATE TABLE IF NOT EXISTS place_experiences (
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
    """,
    "CREATE INDEX IF NOT EXISTS idx_place_experiences_saved_place_uuid ON place_experiences(saved_place_uuid) WHERE deleted_at IS NULL",

    # Triggers: keep experience_rating_average / _median on saved_places in sync
    # with the rating fields of place_experiences (identical to the Flutter app).
    """
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
    """,
    """
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
    """,
    """
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
    """,

    """
    CREATE TABLE IF NOT EXISTS sync_source_experiences (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        sync_source_uuid TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_sync_source_experiences_sync_source_uuid ON sync_source_experiences(sync_source_uuid) WHERE deleted_at IS NULL",

    """
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
    """,
    "CREATE INDEX IF NOT EXISTS idx_place_photos_place ON place_photos(place_uuid) WHERE deleted_at IS NULL",
    "CREATE INDEX IF NOT EXISTS idx_place_photos_stay ON place_photos(stay_uuid) WHERE deleted_at IS NULL",

    """
    CREATE TABLE IF NOT EXISTS p2p_messages (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        author_name TEXT NOT NULL DEFAULT '',
        place_uuid TEXT NOT NULL,
        reply_to_uuid TEXT,
        body TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        FOREIGN KEY (place_uuid) REFERENCES saved_places(uuid) ON DELETE CASCADE
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_messages_place ON p2p_messages(place_uuid) WHERE deleted_at IS NULL",
    "CREATE INDEX IF NOT EXISTS idx_messages_reply ON p2p_messages(reply_to_uuid) WHERE deleted_at IS NULL",
    "CREATE INDEX IF NOT EXISTS idx_messages_created ON p2p_messages(created_at) WHERE deleted_at IS NULL",

    """
    CREATE TABLE IF NOT EXISTS message_attachments (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        message_uuid TEXT NOT NULL,
        photo_uuid TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        FOREIGN KEY (message_uuid) REFERENCES p2p_messages(uuid) ON DELETE CASCADE,
        FOREIGN KEY (photo_uuid) REFERENCES place_photos(uuid) ON DELETE CASCADE
    )
    """,
    "CREATE INDEX IF NOT EXISTS idx_message_attachments_message ON message_attachments(message_uuid) WHERE deleted_at IS NULL",
    "CREATE INDEX IF NOT EXISTS idx_message_attachments_photo ON message_attachments(photo_uuid) WHERE deleted_at IS NULL",

    """
    CREATE TABLE IF NOT EXISTS telegram_connections (
        uuid TEXT PRIMARY KEY,
        device_id TEXT NOT NULL DEFAULT '',
        chat_id TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
    )
    """,

    # Not synced, but present for full schema compatibility.
    """
    CREATE TABLE IF NOT EXISTS trusted_sources (
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
    """,
    "CREATE INDEX IF NOT EXISTS idx_trusted_sources_trusted_device_id ON trusted_sources(trusted_device_id) WHERE deleted_at IS NULL",
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_trusted_sources_device_id ON trusted_sources(trusted_device_id) WHERE deleted_at IS NULL",
]


async def create_tables() -> None:
    """Create all tables and indexes if they don't exist yet."""
    _ensure_db_dir()
    async with aiosqlite.connect(DB_PATH) as conn:
        await conn.execute("PRAGMA foreign_keys=ON")
        for ddl in _DDL:
            await conn.execute(ddl)
        # Idempotent column additions for databases created before schema changes.
        _migrations = [
            "ALTER TABLE sync_sources ADD COLUMN last_sync_ms INTEGER NOT NULL DEFAULT 0",
            "ALTER TABLE virtual_devices ADD COLUMN sync_export_protected INTEGER NOT NULL DEFAULT 0",
            "ALTER TABLE virtual_devices ADD COLUMN sync_import_protected INTEGER NOT NULL DEFAULT 0",
        ]
        for sql in _migrations:
            try:
                await conn.execute(sql)
            except Exception:
                pass  # Column already present — safe to ignore.
        await conn.commit()
    print(f"[db] Database ready at {DB_PATH}")

