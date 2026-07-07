"""
Chaos Tours – Sync Server (FastAPI)
"""
import os
import socket
from contextlib import asynccontextmanager
from typing import Any

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, Security, status
from fastapi.security.api_key import APIKeyHeader
from pydantic import BaseModel
from zeroconf import ServiceInfo
from zeroconf.asyncio import AsyncZeroconf

import database as db
from sync import pull, push

load_dotenv()

API_KEY = os.getenv("API_KEY", "")
_api_key_header = APIKeyHeader(name="X-Api-Key", auto_error=False)
_MDNS_PORT = int(os.getenv("PORT", "8000"))
_MDNS_SERVICE_TYPE = "_chaossync._tcp.local."
_MDNS_SERVICE_NAME = f"chaos-tours-sync.{_MDNS_SERVICE_TYPE}"


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

def _get_local_ip() -> str:
    """Return the primary non-loopback IPv4 address of this machine."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"


@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.create_tables()

    # Announce this server via mDNS so that Flutter clients can discover it
    # automatically without manual IP configuration.
    local_ip = _get_local_ip()
    zeroconf = AsyncZeroconf()
    service_info = ServiceInfo(
        _MDNS_SERVICE_TYPE,
        _MDNS_SERVICE_NAME,
        addresses=[socket.inet_aton(local_ip)],
        port=_MDNS_PORT,
        properties={"version": "1"},
    )
    await zeroconf.async_register_service(service_info, allow_name_change=True)
    try:
        yield
    finally:
        await zeroconf.async_unregister_service(service_info)
        await zeroconf.async_close()


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
    async with db.connect() as conn:
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
    async with db.connect() as conn:
        count = await push(conn, payload.data)
        await conn.commit()
    return {"upserted": count}


@app.get("/places/export", tags=["places"], dependencies=[Depends(verify_api_key)])
async def export_places():
    """Returns all non-deleted saved_places as JSON (for import by other devices via info_url)."""
    async with db.connect() as conn:
        async with conn.execute(
            "SELECT * FROM saved_places WHERE deleted_at IS NULL"
        ) as cursor:
            rows = await cursor.fetchall()
    return [dict(r) for r in rows]
