#!/bin/bash
set -e

echo "📦 Engelsystem Auto-Installer"

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
    echo "🔄 Repo-Update via git pull..."
    cd $TARGET_DIR
    git reset --hard
    git pull
fi

cd $TARGET_DIR/docker

# === 3. Build + Start Container ===
echo "🐳 Baue Docker-Image..."
docker compose build

echo "🚀 Starte Engelsystem..."
docker compose up -d

# === 4. Warte auf Datenbank im Container ===
echo "⏳ Warte, bis Datenbank im Container erreichbar ist..."

until docker compose exec es_database mysqladmin ping -h "localhost" --silent; do
    printf "."
    sleep 1
done

echo ""
echo "🗃️  Führe Datenbank-Migration durch..."
docker compose exec es_server bin/migrate


# === 5. IP-Adresse anzeigen ===
IP=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)

echo ""
echo "✅ Engelsystem läuft!"
echo "🌐 Zugriff: http://$IP:5080"
echo "🔐 (oder via: https://engel.ffw-windischletten.de)"
