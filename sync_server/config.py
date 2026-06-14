"""
Server-side sync table configuration for Chaos Tours.

Each table can independently allow or block:
  - pull: whether the server serves this table's rows to clients
  - push: whether the server accepts incoming rows for this table

Configuration is loaded (in priority order) from:
  1. SYNC_TABLE_CONFIG environment variable (JSON string)
  2. sync_config.json file in the same directory
  3. Built-in defaults (all tables, pull+push enabled)

Example sync_config.json entry:
  {
    "stays":            { "pull": true,  "push": true  },
    "telegram_connections": { "pull": false, "push": true }
  }
"""
import json
import os
from dataclasses import dataclass

from database import SYNC_TABLES

_ALL_TABLES = [name for name, _ in SYNC_TABLES]


@dataclass
class TableSyncConfig:
    pull: bool = True   # Serve rows to clients on /sync/pull
    push: bool = True   # Accept rows from clients on /sync/push


# Defaults: everything enabled.
_DEFAULTS: dict[str, TableSyncConfig] = {t: TableSyncConfig() for t in _ALL_TABLES}

_loaded: dict[str, TableSyncConfig] | None = None


def _load() -> dict[str, TableSyncConfig]:
    raw: dict = {}

    # 1. Env var takes priority.
    env_json = os.getenv("SYNC_TABLE_CONFIG", "").strip()
    if env_json:
        try:
            raw = json.loads(env_json)
        except json.JSONDecodeError as exc:
            print(f"[config] WARNING: SYNC_TABLE_CONFIG is invalid JSON: {exc}")

    # 2. Fall back to sync_config.json.
    if not raw:
        config_path = os.path.join(os.path.dirname(__file__), "sync_config.json")
        if os.path.exists(config_path):
            with open(config_path) as f:
                try:
                    raw = json.load(f)
                except json.JSONDecodeError as exc:
                    print(f"[config] WARNING: sync_config.json is invalid JSON: {exc}")

    config = dict(_DEFAULTS)
    for table, opts in raw.items():
        if isinstance(opts, dict):
            config[table] = TableSyncConfig(
                pull=bool(opts.get("pull", True)),
                push=bool(opts.get("push", True)),
            )
    return config


def get_sync_config() -> dict[str, TableSyncConfig]:
    global _loaded
    if _loaded is None:
        _loaded = _load()
    return _loaded


def get_table_config(table: str) -> TableSyncConfig:
    """Returns the sync config for a table, defaulting to pull+push enabled."""
    return get_sync_config().get(table, TableSyncConfig())
