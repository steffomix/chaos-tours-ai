"""
Sync pull/push logic for Chaos Tours sync server (SQLite / aiosqlite).
"""
from typing import Any

import aiosqlite

from config import get_table_config
from database import SYNC_TABLES, assert_safe_identifier


async def pull(
    conn: aiosqlite.Connection,
    since: int,
    device_id: str,
) -> dict[str, list[dict]]:
    """Return all rows updated after *since* ms, excluding the requesting device.

    Tables with pull=False in the sync config are skipped.
    """
    result: dict[str, list[dict]] = {}
    for name in SYNC_TABLES:
        if not get_table_config(name).pull:
            continue
        safe_name = assert_safe_identifier(name)
        if device_id:
            sql = (
                f"SELECT * FROM {safe_name} "
                f"WHERE updated_at > ? AND device_id != ?"
            )
            params: tuple = (since, device_id)
        else:
            sql = f"SELECT * FROM {safe_name} WHERE updated_at > ?"
            params = (since,)
        async with conn.execute(sql, params) as cursor:
            rows = await cursor.fetchall()
        if rows:
            result[name] = [dict(row) for row in rows]
    return result


async def push(
    conn: aiosqlite.Connection,
    data: dict[str, list[dict[str, Any]]],
) -> int:
    """Upsert all incoming rows (last-write-wins by updated_at).

    Tables with push=False in the sync config are ignored.
    Unknown table names are silently skipped.
    Column names are validated to prevent injection.
    """
    count = 0
    sync_table_set = set(SYNC_TABLES)

    for table_name, rows in data.items():
        if not get_table_config(table_name).push:
            continue
        if table_name not in sync_table_set:
            continue
        safe_table = assert_safe_identifier(table_name)

        for row in rows:
            uuid = row.get("uuid", "")
            if not uuid:
                continue

            # Validate all column names before using them in SQL.
            safe_row = {
                assert_safe_identifier(k): v
                for k, v in row.items()
            }

            async with conn.execute(
                f"SELECT updated_at FROM {safe_table} WHERE uuid = ?", (uuid,)
            ) as cursor:
                existing = await cursor.fetchone()

            if existing is None:
                cols = ", ".join(safe_row.keys())
                placeholders = ", ".join("?" * len(safe_row))
                await conn.execute(
                    f"INSERT OR IGNORE INTO {safe_table} ({cols}) VALUES ({placeholders})",
                    list(safe_row.values()),
                )
            else:
                remote_ts = safe_row.get("updated_at", 0) or 0
                local_ts = existing[0] or 0
                if remote_ts > local_ts:
                    set_clause = ", ".join(f"{k} = ?" for k in safe_row.keys())
                    await conn.execute(
                        f"UPDATE {safe_table} SET {set_clause} WHERE uuid = ?",
                        [*safe_row.values(), uuid],
                    )
            count += 1

    return count
