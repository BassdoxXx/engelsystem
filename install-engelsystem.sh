#!/bin/bash
set -e

echo "📦 Engelsystem Basis-Installer (ohne Cloudflare, ohne Docker-Start)"

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

echo ""
echo "✅ Vorbereitung abgeschlossen. Du kannst jetzt manuell fortfahren:"
echo "➡️  cd /opt/engelsystem/docker"
echo "➡️  docker compose build"
echo "➡️  docker compose up -d"
echo "➡️  docker compose exec es_server bin/migrate"
