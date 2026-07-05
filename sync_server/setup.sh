#!/usr/bin/env bash
# =============================================================================
# Chaos Tours – Sync Server Setup Script
# =============================================================================
# Richtet einen Chaos Tours Sync-Server auf einem Linux-System ein.
# Verwendet SQLite – keine externe Datenbank nötig.
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
echo "  1) Python-Abhängigkeiten installieren + Server starten"
echo "  2) Als systemd-Service einrichten (Server startet automatisch mit dem System)"
echo "  3) Alles der Reihe nach (1 → 2)"
echo "  q) Abbrechen"
echo ""
read -rp "Auswahl [1-3/q]: " CHOICE

case "$CHOICE" in
  1) do_python=true;  do_service=false ;;
  2) do_python=false; do_service=true  ;;
  3) do_python=true;  do_service=true  ;;
  q|Q) info "Abgebrochen."; exit 0 ;;
  *) error "Ungültige Auswahl."; exit 1 ;;
esac

# =============================================================================
# 1. Python-Abhängigkeiten installieren und Server starten
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

  # Datenbankordner anlegen.
  mkdir -p "$SCRIPT_DIR/database"
  success "Datenbankordner: $SCRIPT_DIR/database"

  # .env prüfen / erstellen.
  if [ ! -f "$SCRIPT_DIR/.env" ]; then
    info ".env Datei wird erstellt..."
    cat > "$SCRIPT_DIR/.env" <<EOF
# API-Schlüssel für den Sync-Server.
# Leer lassen um die Authentifizierung zu deaktivieren (nur für lokale Tests empfohlen).
API_KEY=
PORT=8000
EOF
    warn ".env Datei erstellt: $SCRIPT_DIR/.env"
    warn "Tipp: Trage einen API_KEY ein um den Zugang zu sichern."
  else
    success ".env existiert bereits."
  fi

  echo ""
  success "Server kann jetzt gestartet werden:"
  echo "  cd $SCRIPT_DIR && ./start_server.sh"
  echo ""
  read -rp "Server jetzt starten? [j/N]: " START_NOW
  if [[ "$START_NOW" =~ ^[jJyY]$ ]]; then
    info "Server wird gestartet auf Port $PORT..."
    cd "$SCRIPT_DIR"
    "$VENV_DIR/bin/uvicorn" main:app --host 0.0.0.0 --port "$PORT"
  fi
}

# =============================================================================
# 2. Systemd-Service einrichten
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
After=network.target

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

if $do_python; then
  setup_python
fi

if $do_service; then
  setup_service
fi

echo ""
success "Setup abgeschlossen."
