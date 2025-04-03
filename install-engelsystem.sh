#!/bin/bash
set -e

echo "📦 Engelsystem Auto-Installer"

# === 0. Tunnel-Token abfragen ===
if [ -z "$1" ]; then
  read -rp "🌐 Bitte gib deinen Cloudflare Tunnel-Token ein: " TUNNEL_TOKEN
else
  TUNNEL_TOKEN="$1"
fi

# === 1. Docker & Docker Compose installieren ===
if ! command -v docker >/dev/null 2>&1 || ! command -v docker compose >/dev/null 2>&1; then
  echo "🔧 Docker wird installiert..."

  apt update && apt install -y \
      ca-certificates curl gnupg lsb-release git sudo

  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  echo "✅ Docker wurde erfolgreich installiert."
else
  echo "✅ Docker und Docker Compose sind bereits installiert – überspringe."
fi

# === 2. Repo klonen oder aktualisieren ===
REPO_URL="https://github.com/BassdoxXx/engelsystem.git"
TARGET_DIR="/opt/engelsystem"

if [ ! -d "$TARGET_DIR" ]; then
    echo "📥 Klone Engelsystem..."
    git clone $REPO_URL $TARGET_DIR
else
    echo "🔁 Hole aktuelle Version von GitHub..."
    cd $TARGET_DIR
    git fetch origin
    git reset --hard origin/main
fi

cd "$TARGET_DIR/docker"

# === 3. .env schreiben ===
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
  echo "🔐 Erstelle .env mit Tunnel-Token..."
  cat > "$ENV_FILE" <<EOF
CF_TUNNEL_TOKEN=$TUNNEL_TOKEN
COMPOSE_PROJECT_NAME=engelsystem
EOF
else
  echo "🛡️  .env existiert bereits – unverändert."
fi

# === 4. Prüfen ob Container schon laufen ===
if docker compose ps | grep -q 'es_server'; then
    echo "♻️ Container laufen bereits – führe Rebuild & Restart durch..."
    docker compose down
    docker compose --env-file .env up -d
else
    echo "🐳 Baue Docker-Image (Erstinstallation)..."
    docker compose --env-file .env build

    echo "🚀 Starte Engelsystem..."
    docker compose --env-file .env up -d
fi

# === 5. Warte auf Datenbank im Container ===
echo "⏳ Warte, bis Datenbank im Container erreichbar ist..."
until docker compose exec es_database mysqladmin ping -h "localhost" --silent; do
    printf "."
    sleep 1
done

echo ""
echo "🗃️  Führe Datenbank-Migration durch..."
docker compose exec es_server bin/migrate

# === 6. IP-Adresse anzeigen ===
IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)

echo ""
echo "✅ Engelsystem läuft!"
echo "🌐 Zugriff: http://$IP:5080"
echo "🔐 (oder via: https://engel.ffw-windischletten.de)"
