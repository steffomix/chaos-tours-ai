# Chaos Tours – Sync Server

Schlanker FastAPI-Service der mehrere Chaos-Tours-Geräte über eine gemeinsame
SQLite-Datenbank synchronisiert.

Die Datenbankdatei (`database/chaos_tours.sqlite`) hat exakt dasselbe Schema wie
die App selbst – sie kann jederzeit direkt zwischen Server und App kopiert werden.

---

## Schnellstart mit setup.sh (empfohlen)

```bash
cd sync_server
chmod +x setup.sh
./setup.sh
```

Das Skript richtet die Python-Umgebung ein und fragt, ob der Server als
systemd-Dienst (Autostart) eingerichtet werden soll.

---

## Manuelle Installation

### Voraussetzungen

- Python 3.11+
- Keine externe Datenbank nötig

### Python-Umgebung einrichten

```bash
cd sync_server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Konfiguration (optional)

```bash
# .env anlegen – beide Werte sind optional
cat > .env <<EOF
API_KEY=mein-geheimer-schluessel
PORT=8000
EOF
```

`API_KEY` leer lassen (oder weglassen) um die Authentifizierung zu deaktivieren.

### Server starten

```bash
./start_server.sh
# oder direkt:
source .venv/bin/activate
uvicorn main:app --host 0.0.0.0 --port 8000
```

Der Server ist nun erreichbar unter `http://<IP-Adresse>:8000`.
Die API-Dokumentation gibt es unter `http://<IP-Adresse>:8000/docs`.

---

## Datenbankdatei

Die SQLite-Datenbank liegt unter `./database/chaos_tours.sqlite`.

**Datenbank aus der App importieren:**
Einfach die `chaos_tours.sqlite` vom Gerät (z. B. per `adb pull` oder
Datei-Manager) in den `database/`-Ordner kopieren und den Server neu starten.

**Datenbank in die App importieren:**
Die `database/chaos_tours.sqlite` vom Server auf das Gerät kopieren und
in den App-Datenbankpfad legen.

---

## Als systemd-Service einrichten

```bash
./setup.sh   # Option 2 oder 3 wählen
```

Oder manuell:

```bash
sudo nano /etc/systemd/system/chaos-tours-sync.service
```

```ini
[Unit]
Description=Chaos Tours Sync Server
After=network.target

[Service]
Type=simple
User=DEIN_BENUTZER
WorkingDirectory=/pfad/zu/sync_server
ExecStart=/pfad/zu/sync_server/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=on-failure
EnvironmentFile=/pfad/zu/sync_server/.env

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now chaos-tours-sync
sudo journalctl -u chaos-tours-sync -f
```

---

## API-Endpunkte

| Methode | Pfad            | Beschreibung                              |
|---------|-----------------|-------------------------------------------|
| GET     | `/health`       | Statuscheck                               |
| GET     | `/sync/pull`    | Zeilen neuer als `?since=<ms>` abrufen    |
| POST    | `/sync/push`    | Zeilen vom Gerät auf den Server schreiben |
| GET     | `/places/export`| Alle Orte als JSON exportieren            |
