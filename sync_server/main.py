"""
Chaos Tours – Sync Server (FastAPI)
"""
import os
from contextlib import asynccontextmanager
from typing import Any

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, Security, status
from fastapi.security.api_key import APIKeyHeader
from pydantic import BaseModel
from sqlalchemy import select

import database as db
from database import get_engine, saved_places
from sync import pull, push

load_dotenv()

API_KEY = os.getenv("API_KEY", "")
_api_key_header = APIKeyHeader(name="X-Api-Key", auto_error=False)


# ---------------------------------------------------------------------------
# Auth dependency
# ---------------------------------------------------------------------------

def verify_api_key(key: str | None = Security(_api_key_header)) -> None:
    if not API_KEY:
        return  # Auth disabled
    if key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key",
        )


# ---------------------------------------------------------------------------
# Lifespan
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.create_tables()
    yield


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="Chaos Tours Sync Server",
    version="1.0.0",
    lifespan=lifespan,
)


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health", tags=["misc"])
async def health():
    return {"status": "ok"}


# ---------------------------------------------------------------------------
# Sync – Pull
# ---------------------------------------------------------------------------

@app.get("/sync/pull", tags=["sync"], dependencies=[Depends(verify_api_key)])
async def sync_pull(since: int = 0, device_id: str = ""):
    engine = get_engine()
    async with engine.connect() as conn:
        data = await pull(conn, since, device_id)
    return data


# ---------------------------------------------------------------------------
# Sync – Push
# ---------------------------------------------------------------------------

class PushPayload(BaseModel):
    device_id: str = ""
    data: dict[str, list[dict[str, Any]]]


@app.post("/sync/push", tags=["sync"], dependencies=[Depends(verify_api_key)])
async def sync_push(payload: PushPayload):
    engine = get_engine()
    async with engine.begin() as conn:
        count = await push(conn, payload.data)
    return {"upserted": count}


@app.get("/places/export", tags=["places"], dependencies=[Depends(verify_api_key)])
async def export_places():
    """Returns all non-deleted saved_places as JSON (for import by other devices via info_url)."""
    engine = get_engine()
    async with engine.connect() as conn:
        rows = (
            await conn.execute(
                select(saved_places).where(saved_places.c.deleted_at.is_(None))
            )
        ).mappings().all()
    return [dict(r) for r in rows]
