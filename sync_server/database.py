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
def _sync_cols():
    return [
        Column("updated_at", BigInteger, nullable=False, default=0),
        Column("deleted_at", BigInteger, nullable=True),
        Column("device_id", String, nullable=False, default=""),
    ]

saved_places = Table(
    "saved_places",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("name", String, nullable=False),
    Column("lat", Float, nullable=False),
    Column("lng", Float, nullable=False),
    Column("radius", Float, nullable=False, default=50.0),
    Column("notes", Text, nullable=False, default=""),
    Column("group_uuid", String, nullable=True),
    Column("created_at", BigInteger, nullable=False, default=0),
    Column("interval_enabled", Integer, nullable=False, default=0),
    Column("interval_days", Integer, nullable=True),
    Column("origin_type", Integer, nullable=False, default=0),
    Column("origin_source_uuid", String, nullable=True),
    Column("website", String, nullable=False, default=""),
    Column("email", String, nullable=False, default=""),
    Column("phone", String, nullable=False, default=""),
    *_sync_cols(),
)

place_groups = Table(
    "place_groups",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("name", String, nullable=False),
    Column("calendar_id", String, nullable=True),
    Column("include_notes", Integer, nullable=False, default=1),
    Column("include_persons", Integer, nullable=False, default=1),
    Column("include_activities", Integer, nullable=False, default=1),
    Column("is_auto_group", Integer, nullable=False, default=0),
    Column("place_type", Integer, nullable=False, default=0),
    *_sync_cols(),
)

stays = Table(
    "stays",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("place_uuid", String, nullable=True),
    Column("start_time", BigInteger, nullable=False),
    Column("end_time", BigInteger, nullable=True),
    Column("notes", Text, nullable=False, default=""),
    Column("calendar_event_id", String, nullable=True),
    Column("address", Text, nullable=True),
    Column("status", String, nullable=False, default="detecting"),
    Column("is_interval", Integer, nullable=False, default=1),
    *_sync_cols(),
)

persons = Table(
    "persons",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("name", String, nullable=False),
    Column("role", String, nullable=False, default=""),
    *_sync_cols(),
)

activities = Table(
    "activities",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("name", String, nullable=False),
    *_sync_cols(),
)

stay_persons = Table(
    "stay_persons",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("stay_uuid", String, nullable=False),
    Column("person_uuid", String, nullable=True),
    Column("name", String, nullable=False),
    *_sync_cols(),
)

stay_activities = Table(
    "stay_activities",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("stay_uuid", String, nullable=False),
    Column("activity_uuid", String, nullable=True),
    Column("description", Text, nullable=False),
    *_sync_cols(),
)

aktivitaeten = Table(
    "aktivitaeten",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("name", String, nullable=False),
    Column("gps_interval_seconds", Integer, nullable=False, default=15),
    Column("stay_detection_seconds", Integer, nullable=False, default=180),
    Column("auto_place_seconds", Integer, nullable=False, default=900),
    Column("default_radius_meters", Float, nullable=False, default=50.0),
    Column("auto_create_places", Integer, nullable=False, default=1),
    Column("auto_place_group_uuid", String, nullable=True),
    Column("default_place_group_uuid", String, nullable=True),
    Column("timeline_history_days", Integer, nullable=False, default=7),
    Column("search_country", String, nullable=False, default=""),
    Column("scheduler_color_range", Integer, nullable=False, default=14),
    Column("scheduler_group_ids", String, nullable=False, default=""),
    *_sync_cols(),
)

sync_sources = Table(
    "sync_sources",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("name", String, nullable=False),
    Column("sync_url", String, nullable=False, default=""),
    Column("api_key", String, nullable=False, default=""),
    Column("info_url", String, nullable=False, default=""),
    Column("description", Text, nullable=False, default=""),
    Column("sync_options", Text, nullable=False, default="{}"),
    *_sync_cols(),
)

place_experiences = Table(
    "place_experiences",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("saved_place_uuid", String, nullable=False),
    Column("text", Text, nullable=False, default=""),
    Column("rating_dangerous_friendly", Integer, nullable=False, default=0),
    Column("rating_fraud_reliable", Integer, nullable=False, default=0),
    Column("rating_dismissive_accommodation", Integer, nullable=False, default=0),
    Column("rating_food", Integer, nullable=False, default=0),
    Column("rating_equipment", Integer, nullable=False, default=0),
    Column("rating_transport", Integer, nullable=False, default=0),
    Column("created_at", BigInteger, nullable=False, default=0),
    *_sync_cols(),
)

sync_source_experiences = Table(
    "sync_source_experiences",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("sync_source_uuid", String, nullable=False),
    Column("text", Text, nullable=False, default=""),
    Column("created_at", BigInteger, nullable=False, default=0),
    *_sync_cols(),
)

place_photos = Table(
    "place_photos",
    metadata,
    Column("uuid", String, primary_key=True),
    Column("place_uuid", String, nullable=True),
    Column("stay_uuid", String, nullable=True),
    Column("caption", Text, nullable=False, default=""),
    Column("taken_at", BigInteger, nullable=False, default=0),
    Column("photo_data", Text, nullable=False, default=""),
    Column("created_at", BigInteger, nullable=False, default=0),
    *_sync_cols(),
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
    ("sync_sources", sync_sources),
    ("place_experiences", place_experiences),
    ("sync_source_experiences", sync_source_experiences),
    ("place_photos", place_photos),
]


async def create_tables() -> None:
    """Create all tables if they don't exist yet."""
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(metadata.create_all)
