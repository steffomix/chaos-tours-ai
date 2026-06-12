# Chaos Tours – Sync Server

Lightweight FastAPI service that bridges Android SQLite devices with a shared PostgreSQL database.

## Voraussetzungen

- Python 3.11+
- PostgreSQL 14+ (lokal oder via Docker)

## Schnellstart

```bash
cd sync_server
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# .env anpassen (DATABASE_URL, API_KEY)
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## Endpunkte

| Methode | Pfad | Beschreibung |
|---------|------|--------------|
| GET | `/health` | Statuscheck |
| GET | `/sync/pull?since=<ms>&device_id=<id>` | Delta aller Tabellen seit Timestamp |
| POST | `/sync/push` | Batch-Upsert vom Client |
| GET | `/places/export` | Öffentliche Orte als JSON (für Web-Quellen-Import) |

## Auth

Alle Endpunkte (außer `/health`) erfordern den Header `X-Api-Key: <KEY>` wenn `API_KEY` in `.env` gesetzt ist.

## LibreOffice / Direkt-Zugriff

LibreOffice Base kann direkt über JDBC auf die PostgreSQL-Datenbank zugreifen:

- Treiber: PostgreSQL JDBC (`postgresql-<version>.jar`)
- JDBC-URL: `jdbc:postgresql://localhost:5432/chaos_tours`
- Benutzer/Passwort: wie in `.env` konfiguriert

## Device-to-Device

Jedes Android-Gerät kann mit jedem anderen Gerät synchronisieren, das diesen Server (oder einen kompatiblen) betreibt. Die Peer-URL im App-Einstellungen-Screen konfigurieren.
