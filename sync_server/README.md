# Chaos Tours – Sync Server

Lightweight FastAPI service that bridges Android SQLite devices with a shared PostgreSQL database.

## Schnellstart mit setup.sh (empfohlen)

```bash
cd sync_server
chmod +x setup.sh
./setup.sh
```

Das Skript führt durch alle Schritte (PostgreSQL, Python-Umgebung, optionaler Systemd-Service).

---

## Manuelle Installation

### Voraussetzungen

- Python 3.11+
- PostgreSQL 14+

### Python-Umgebung einrichten

```bash
cd sync_server
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# .env anpassen (DATABASE_URL, API_KEY)
uvicorn main:app --host 0.0.0.0 --port 8000
```

---

## PostgreSQL auf Linux einrichten (detaillierte Anleitung)

### 1. PostgreSQL installieren

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

Überprüfen ob der Dienst läuft:
```bash
sudo systemctl status postgresql
```

### 2. Datenbankbenutzer und Datenbank anlegen

```bash
# Als postgres-Superuser wechseln
sudo -i -u postgres

# PostgreSQL-Benutzer 'chaos' anlegen (alle Fragen mit n beantworten)
createuser --interactive
# Gibt man 'chaos' als Namen ein → auf alle y/n-Fragen 'n' eingeben

# Datenbank 'chaos_tours' mit Eigentümer 'chaos' anlegen
createdb -O chaos chaos_tours

# In die PostgreSQL-Shell wechseln
psql

# Passwort für Benutzer 'chaos' setzen
ALTER USER chaos WITH PASSWORD 'chaos';

# Shell und Benutzer verlassen
\q
exit
```

### 3. .env Datei anpassen

```ini
DATABASE_URL=postgresql+asyncpg://chaos:chaos@localhost:5432/chaos_tours
API_KEY=mein-geheimer-api-schluessel
```

**Hinweis:** Wird `API_KEY` leer gelassen, ist kein Schlüssel erforderlich (nur für lokale Tests empfohlen).

### 4. Tabellen anlegen (automatisch beim ersten Start)

Die Tabellen werden beim ersten Start des Servers automatisch angelegt.

### 5. Server starten

```bash
source .venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000
```

Der Server ist nun erreichbar unter `http://<IP-Adresse>:8000`.

---

## Als systemd-Service einrichten (Autostart)

### Service-Datei erstellen

```bash
sudo nano /etc/systemd/system/chaos-tours-sync.service
```

Inhalt (Pfade anpassen):
```ini
[Unit]
Description=Chaos Tours Sync Server
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=DEIN_BENUTZERNAME
WorkingDirectory=/pfad/zum/sync_server
ExecStart=/pfad/zum/sync_server/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=on-failure
RestartSec=5
EnvironmentFile=/pfad/zum/sync_server/.env

[Install]
WantedBy=multi-user.target
```

### Service aktivieren und starten

```bash
sudo systemctl daemon-reload
sudo systemctl enable chaos-tours-sync
sudo systemctl start chaos-tours-sync
```

### Service-Status prüfen

```bash
sudo systemctl status chaos-tours-sync
# Logs anzeigen:
sudo journalctl -u chaos-tours-sync -f
```

---

## Firewall (UFW)

Falls UFW aktiv ist, Port 8000 freigeben:

```bash
sudo ufw allow 8000/tcp
sudo ufw reload
```

---

## API-Endpunkte

| Methode | Pfad | Beschreibung |
|---------|------|--------------|
| GET | `/health` | Statuscheck |
| GET | `/sync/pull?since=<ms>&device_id=<id>` | Delta aller Tabellen seit Timestamp |
| POST | `/sync/push` | Batch-Upsert vom Client |
| GET | `/places/export` | Orte als JSON (über info_url abrufbar) |

## Auth

Alle Endpunkte (außer `/health`) erfordern den Header `X-Api-Key: <KEY>` wenn `API_KEY` in `.env` gesetzt ist.

## Synchronisierte Tabellen

Der Server verwaltet folgende Tabellen, die per Delta-Sync übertragen werden können:

| Tabelle | Inhalt |
|---------|--------|
| `saved_places` | Gespeicherte Orte |
| `place_groups` | Ortsgruppen |
| `stays` | Aufenthalte |
| `persons` | Personen |
| `activities` | Aktivitäten (Profile) |
| `stay_persons` | Aufenthalt ↔ Person Zuordnungen |
| `stay_activities` | Aufenthalt ↔ Aktivität Zuordnungen |
| `aktivitaeten` | Freitext-Aktivitäten je Aufenthalt |
| `sync_sources` | Sync-Quellen-Konfiguration |
| `place_experiences` | Ortserfahrungen & Bewertungen |
| `sync_source_experiences` | Erfahrungs-Feed-Zuordnungen |
| `place_photos` | Fotos (Base64) für Orte und Aufenthalte |
| `telegram_connections` | Telegram-Bot-Verbindungen |

## Sync-Optionen (Server-Seite)

Der Server nimmt alle Daten an die der Client schickt (Push) und gibt alle geänderten Daten zurück (Pull). Welche Tabellen tatsächlich synchronisiert werden, wird auf dem Android-Gerät pro **Sync-Quelle** konfiguriert.

**Standardmäßig** sendet die App nur `saved_places` (nur Einfügen). Weitere Tabellen und Optionen (Bearbeiten, Löschen) müssen in der App unter **Einstellungen → Sync-Quellen → Sync-Optionen** aktiviert werden.

## Erfahrungs-Feeds

Eine Sync-Quelle kann als **Erfahrungs-Feed** konfiguriert werden. Die App liest dann `place_experiences` von diesem Server (nur Lesen) und zeigt sie bei passenden Orten als externe Bewertungen an – ohne eigene Daten zu schreiben.

## LibreOffice / Direkt-Zugriff

LibreOffice Base kann direkt über JDBC auf die PostgreSQL-Datenbank zugreifen:

- Treiber: PostgreSQL JDBC (`postgresql-<version>.jar`)
- JDBC-URL: `jdbc:postgresql://localhost:5432/chaos_tours`
- Benutzer/Passwort: wie in `.env` konfiguriert

