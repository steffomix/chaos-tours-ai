#!/usr/bin/env bash
# =============================================================================
# Chaos Tours – Sync Server Setup Script
# =============================================================================
# Richtet einen Chaos Tours Sync-Server auf einem Linux-System ein.
# Unterstützt:
#   1. Nur Abhängigkeiten installieren und Server starten
#   2. PostgreSQL installieren und konfigurieren (für unerfahrene Benutzer)
#   3. Als systemd-Service einrichten (optionaler Autostart)
#
# Verwendung:
#   chmod +x setup.sh
#   ./setup.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="chaos-tours-sync"
SERVICE_USER="$USER"
VENV_DIR="$SCRIPT_DIR/.venv"
PORT=8000

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[FEHLER]${NC} $*" >&2; }

# =============================================================================
# Menü
# =============================================================================
echo ""
echo "=== Chaos Tours Sync Server Setup ==="
echo ""
echo "Was soll eingerichtet werden?"
echo "  1) Nur Python-Abhängigkeiten installieren + Server starten"
echo "  2) PostgreSQL installieren und konfigurieren (empfohlen für Neulinge)"
echo "  3) Systemd-Service einrichten (Server als Dienst beim Systemstart)"
echo "  4) Alles der Reihe nach (2 → 1 → 3)"
echo "  q) Abbrechen"
echo ""
read -rp "Auswahl [1-4/q]: " CHOICE

case "$CHOICE" in
  1) do_python=true;  do_postgres=false; do_service=false ;;
  2) do_python=false; do_postgres=true;  do_service=false ;;
  3) do_python=false; do_postgres=false; do_service=true  ;;
  4) do_python=true;  do_postgres=true;  do_service=true  ;;
  q|Q) info "Abgebrochen."; exit 0 ;;
  *) error "Ungültige Auswahl."; exit 1 ;;
esac

# =============================================================================
# 1. PostgreSQL einrichten
# =============================================================================
setup_postgres() {
  info "PostgreSQL wird eingerichtet..."

  # Prüfen ob PostgreSQL installiert ist.
  if ! command -v psql &>/dev/null; then
    info "PostgreSQL wird installiert (apt)..."
    sudo apt-get update -qq
    sudo apt-get install -y postgresql postgresql-contrib
    success "PostgreSQL installiert."
  else
    success "PostgreSQL ist bereits installiert."
  fi

  # Sicherstellen, dass der PostgreSQL-Dienst läuft.
  if ! sudo systemctl is-active --quiet postgresql; then
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    success "PostgreSQL-Dienst gestartet."
  fi

  # .env lesen oder Standardwerte verwenden.
  DB_USER="chaos"
  DB_PASS="chaos"
  DB_NAME="chaos_tours"
  DB_HOST="localhost"
  DB_PORT="5432"

  if [ -f "$SCRIPT_DIR/.env" ]; then
    # Werte aus .env lesen falls vorhanden.
    DB_USER=$(grep -E '^DB_USER=' "$SCRIPT_DIR/.env" | cut -d= -f2 | tr -d '"' || echo "chaos")
    DB_PASS=$(grep -E '^DB_PASS=' "$SCRIPT_DIR/.env" | cut -d= -f2 | tr -d '"' || echo "chaos")
    DB_NAME=$(grep -E '^DB_NAME=' "$SCRIPT_DIR/.env" | cut -d= -f2 | tr -d '"' || echo "chaos_tours")
  fi

  echo ""
  warn "PostgreSQL-Konfiguration:"
  echo "  Benutzer:  $DB_USER"
  echo "  Datenbank: $DB_NAME"
  echo "  Host:      $DB_HOST:$DB_PORT"
  echo ""
  read -rp "Benutzer und Passwort anlegen? (Bereits vorhandene werden übersprungen) [j/N]: " CONFIRM
  if [[ "$CONFIRM" =~ ^[jJyY]$ ]]; then
    # Benutzer anlegen (ignoriert Fehler falls er existiert).
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 2>/dev/null \
      || warn "Benutzer '$DB_USER' existiert bereits (wird übersprungen)."

    # Datenbank anlegen.
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" 2>/dev/null \
      || warn "Datenbank '$DB_NAME' existiert bereits (wird übersprungen)."

    # Berechtigungen.
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    success "Datenbank eingerichtet: $DB_NAME (Eigentümer: $DB_USER)"
  fi

  # .env erstellen falls nicht vorhanden.
  if [ ! -f "$SCRIPT_DIR/.env" ]; then
    info ".env Datei wird erstellt..."
    cat > "$SCRIPT_DIR/.env" <<EOF
DATABASE_URL=postgresql+asyncpg://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}
API_KEY=mein-geheimer-schluessel
# API_KEY leer lassen um Authentifizierung zu deaktivieren
EOF
    success ".env Datei erstellt: $SCRIPT_DIR/.env"
    warn "Bitte den API_KEY in .env anpassen!"
  else
    success ".env existiert bereits."
  fi
}

# =============================================================================
# 2. Python-Abhängigkeiten installieren und Server starten
# =============================================================================
setup_python() {
  info "Python-Umgebung wird eingerichtet..."

  # Python3 prüfen.
  if ! command -v python3 &>/dev/null; then
    error "Python3 ist nicht installiert. Bitte installiere Python 3.11+."
    exit 1
  fi

  PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
  info "Python-Version: $PYTHON_VERSION"

  # Virtualenv anlegen.
  if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    success "Virtualenv erstellt: $VENV_DIR"
  else
    success "Virtualenv existiert bereits."
  fi

  # Abhängigkeiten installieren.
  info "Abhängigkeiten werden installiert..."
  "$VENV_DIR/bin/pip" install --quiet --upgrade pip
  "$VENV_DIR/bin/pip" install --quiet -r "$SCRIPT_DIR/requirements.txt"
  success "Abhängigkeiten installiert."

  # .env prüfen.
  if [ ! -f "$SCRIPT_DIR/.env" ]; then
    if [ -f "$SCRIPT_DIR/.env.example" ]; then
      cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
      warn ".env aus .env.example erstellt – bitte anpassen!"
    else
      warn "Keine .env Datei gefunden. Bitte manuell erstellen."
    fi
  fi

  echo ""
  success "Server kann jetzt gestartet werden:"
  echo "  cd $SCRIPT_DIR"
  echo "  source .venv/bin/activate"
  echo "  uvicorn main:app --host 0.0.0.0 --port $PORT"
  echo ""
  read -rp "Server jetzt starten? [j/N]: " START_NOW
  if [[ "$START_NOW" =~ ^[jJyY]$ ]]; then
    info "Server wird gestartet auf Port $PORT..."
    cd "$SCRIPT_DIR"
    "$VENV_DIR/bin/uvicorn" main:app --host 0.0.0.0 --port "$PORT"
  fi
}

# =============================================================================
# 3. Systemd-Service einrichten
# =============================================================================
setup_service() {
  info "Systemd-Service wird eingerichtet..."

  if [ ! -d "$VENV_DIR" ]; then
    error "Virtualenv nicht gefunden. Bitte zuerst Option 1 (Python-Setup) ausführen."
    exit 1
  fi

  SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
  UVICORN_BIN="$VENV_DIR/bin/uvicorn"

  cat > "/tmp/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Chaos Tours Sync Server
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${UVICORN_BIN} main:app --host 0.0.0.0 --port ${PORT}
Restart=on-failure
RestartSec=5
EnvironmentFile=${SCRIPT_DIR}/.env

[Install]
WantedBy=multi-user.target
EOF

  sudo mv "/tmp/${SERVICE_NAME}.service" "$SERVICE_FILE"
  sudo systemctl daemon-reload
  sudo systemctl enable "$SERVICE_NAME"

  echo ""
  read -rp "Service jetzt starten? [j/N]: " START_SVC
  if [[ "$START_SVC" =~ ^[jJyY]$ ]]; then
    sudo systemctl start "$SERVICE_NAME"
    sleep 2
    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
      success "Service '$SERVICE_NAME' läuft."
    else
      error "Service konnte nicht gestartet werden."
      sudo journalctl -u "$SERVICE_NAME" --no-pager -n 20
    fi
  fi

  success "Service eingerichtet: $SERVICE_FILE"
  echo ""
  echo "  Service-Steuerung:"
  echo "    sudo systemctl start   $SERVICE_NAME"
  echo "    sudo systemctl stop    $SERVICE_NAME"
  echo "    sudo systemctl restart $SERVICE_NAME"
  echo "    sudo systemctl status  $SERVICE_NAME"
  echo "    sudo journalctl -u     $SERVICE_NAME -f"
}

# =============================================================================
# Ausführung
# =============================================================================

if $do_postgres; then
  setup_postgres
fi

if $do_python; then
  setup_python
fi

if $do_service; then
  setup_service
fi

echo ""
success "Setup abgeschlossen."
