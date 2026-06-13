# Chaos Tours – Sync Server

Lightweight FastAPI service that bridges Android SQLite devices with a shared PostgreSQL database.

## Voraussetzungen

- Python 3.11+
- PostgreSQL 14+ (lokal oder via Docker)

## Postgres Datenbank und -benutzer erstellen


Erstellt einen Benutzer und Datenbank passend für die Standardkonfiguration dieser App. Andere Namen und Passwörter müssen in .env entsprechend angepasst werden.

```

# Benutzer wechseln
sudo -i -u postgres

# Erstelle Postgres Benutzer 'chaos'
# Beantworte alle y/n Fragen mit n
createuser --interactive

# Erstelle Datenbank für -O Eigentümer Datenbankname
createdb -O chaos chaos

# Starte Postgres Client
psql

# Setze Passwort für Benutzer
ALTER USER chaos WITH PASSWORD 'chaos';

# exit postgres and user
\q
exit
```

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

