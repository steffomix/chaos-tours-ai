"""
Sync pull/push logic for Chaos Tours sync server.
"""
from typing import Any

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncConnection

from config import get_table_config
from database import SYNC_TABLES


async def pull(
    conn: AsyncConnection,
    since: int,
    device_id: str,
) -> dict[str, list[dict]]:
    """Return all rows updated after [since] ms, excluding the requesting device.

    Tables with pull=false in sync_config.json (or SYNC_TABLE_CONFIG) are skipped.
    """
    result: dict[str, list[dict]] = {}
    for name, table in SYNC_TABLES:
        if not get_table_config(name).pull:
            continue
        stmt = select(table).where(table.c.updated_at > since)
        if device_id:
            stmt = stmt.where(table.c.device_id != device_id)
        rows = (await conn.execute(stmt)).mappings().all()
        if rows:
            result[name] = [dict(r) for r in rows]
    return result


async def push(
    conn: AsyncConnection,
    data: dict[str, list[dict[str, Any]]],
) -> int:
    """Upsert all incoming rows (last-write-wins per updated_at).

    Tables with push=false in sync_config.json (or SYNC_TABLE_CONFIG) are ignored.
    """
    count = 0
    table_map = {name: tbl for name, tbl in SYNC_TABLES}

    for table_name, rows in data.items():
        if not get_table_config(table_name).push:
            continue
        table = table_map.get(table_name)
        if table is None:
            continue
        for row in rows:
            uuid = row.get("uuid", "")
            if not uuid:
                continue

            # Check existing row's updated_at
            existing = (
                await conn.execute(
                    select(table.c.updated_at).where(table.c.uuid == uuid)
                )
            ).first()

            if existing is None:
                await conn.execute(table.insert().values(**row))
            else:
                remote_ts = row.get("updated_at", 0) or 0
                local_ts = existing[0] or 0
                if remote_ts > local_ts:
                    await conn.execute(
                        table.update().where(table.c.uuid == uuid).values(**row)
                    )
            count += 1

    return count
