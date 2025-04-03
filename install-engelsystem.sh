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
    cd "$TARGET_DIR"
    echo "🔁 Setze lokale Änderungen zurück und hole aktuelle Version..."
    git fetch --all
    git reset --hard origin/main
    git clean -fd
fi

cd $TARGET_DIR/docker

# === 3. .env schreiben ===
echo "🔐 Schreibe .env mit Token und Projektname..."
cat > .env <<EOF
TUNNEL_TOKEN=$TUNNEL_TOKEN
COMPOSE_PROJECT_NAME=engelsystem
EOF


# === 4. Build + Start Container ===
echo "🐳 Baue Docker-Image..."
docker compose build

echo "🚀 Starte Engelsystem..."
docker compose up -d

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
