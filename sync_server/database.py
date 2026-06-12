"""
SQLAlchemy async setup and table definitions for Chaos Tours sync server.
"""
import os
from dotenv import load_dotenv
from sqlalchemy import (
    BigInteger,
    Column,
    Float,
    Integer,
    MetaData,
    String,
    Table,
    Text,
)
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://chaos:chaos@localhost:5432/chaos_tours",
)

_engine: AsyncEngine | None = None


def get_engine() -> AsyncEngine:
    global _engine
    if _engine is None:
        _engine = create_async_engine(DATABASE_URL, echo=False)
    return _engine


metadata = MetaData()

# ---------------------------------------------------------------------------
# Sync columns shared across all tables
# ---------------------------------------------------------------------------
_sync_cols = [
    Column("uuid", String, nullable=False, default=""),
    Column("updated_at", BigInteger, nullable=False, default=0),
    Column("deleted_at", BigInteger, nullable=True),
    Column("device_id", String, nullable=False, default=""),
]

saved_places = Table(
    "saved_places",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("name", String, nullable=False),
    Column("lat", Float, nullable=False),
    Column("lng", Float, nullable=False),
    Column("radius", Float, nullable=False, default=50.0),
    Column("notes", Text, nullable=False, default=""),
    Column("group_id", Integer, nullable=True),
    Column("created_at", BigInteger, nullable=False, default=0),
    Column("interval_enabled", Integer, nullable=False, default=0),
    Column("interval_days", Integer, nullable=True),
    Column("origin_type", Integer, nullable=False, default=0),
    Column("origin_source_uuid", String, nullable=True),
    *_sync_cols,
)

place_groups = Table(
    "place_groups",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("name", String, nullable=False),
    Column("calendar_id", String, nullable=True),
    Column("include_notes", Integer, nullable=False, default=1),
    Column("include_persons", Integer, nullable=False, default=1),
    Column("include_activities", Integer, nullable=False, default=1),
    Column("is_auto_group", Integer, nullable=False, default=0),
    Column("place_type", Integer, nullable=False, default=0),
    *_sync_cols,
)

stays = Table(
    "stays",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("place_id", Integer, nullable=True),
    Column("start_time", BigInteger, nullable=False),
    Column("end_time", BigInteger, nullable=True),
    Column("notes", Text, nullable=False, default=""),
    Column("calendar_event_id", String, nullable=True),
    Column("address", Text, nullable=True),
    Column("status", String, nullable=False, default="detecting"),
    Column("is_interval", Integer, nullable=False, default=1),
    *_sync_cols,
)

persons = Table(
    "persons",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("name", String, nullable=False),
    Column("role", String, nullable=False, default=""),
    *_sync_cols,
)

activities = Table(
    "activities",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("name", String, nullable=False),
    *_sync_cols,
)

stay_persons = Table(
    "stay_persons",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("stay_id", Integer, nullable=False),
    Column("person_id", Integer, nullable=True),
    Column("name", String, nullable=False),
    *_sync_cols,
)

stay_activities = Table(
    "stay_activities",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("stay_id", Integer, nullable=False),
    Column("activity_id", Integer, nullable=True),
    Column("description", Text, nullable=False),
    *_sync_cols,
)

aktivitaeten = Table(
    "aktivitaeten",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("name", String, nullable=False),
    Column("gps_interval_seconds", Integer, nullable=False, default=15),
    Column("stay_detection_seconds", Integer, nullable=False, default=180),
    Column("auto_place_seconds", Integer, nullable=False, default=900),
    Column("default_radius_meters", Float, nullable=False, default=50.0),
    Column("auto_create_places", Integer, nullable=False, default=1),
    Column("auto_place_group_id", Integer, nullable=True),
    Column("default_place_group_id", Integer, nullable=True),
    Column("timeline_history_days", Integer, nullable=False, default=7),
    Column("search_country", String, nullable=False, default=""),
    Column("scheduler_color_range", Integer, nullable=False, default=14),
    Column("scheduler_group_ids", String, nullable=False, default=""),
    *_sync_cols,
)

web_sources = Table(
    "web_sources",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("name", String, nullable=False),
    Column("url", String, nullable=False),
    Column("notes", Text, nullable=False, default=""),
    Column("experience", Text, nullable=False, default=""),
    Column("api_key", String, nullable=False, default=""),
    *_sync_cols,
)

# Ordered by foreign-key dependency (parents before children).
SYNC_TABLES = [
    ("place_groups", place_groups),
    ("saved_places", saved_places),
    ("persons", persons),
    ("activities", activities),
    ("stays", stays),
    ("stay_persons", stay_persons),
    ("stay_activities", stay_activities),
    ("aktivitaeten", aktivitaeten),
    ("web_sources", web_sources),
]


async def create_tables() -> None:
    """Create all tables if they don't exist yet."""
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(metadata.create_all)
