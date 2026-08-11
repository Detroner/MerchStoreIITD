#!/usr/bin/env bash
set -euo pipefail

# Cross-platform setup for Linux/macOS
# Usage: sudo ./scripts/setup-unix.sh  OR ./scripts/setup-unix.sh (will use sudo when needed)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

info(){ echo "[INFO] $*"; }
err(){ echo "[ERROR] $*" >&2; }

need_cmd(){ command -v "$1" >/dev/null 2>&1 || return 1; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if need_cmd sudo; then
    SUDO="sudo"
  else
    err "This script needs administrative rights to install packages. Re-run as root or install sudo."
    exit 1
  fi
fi

# Detect package manager
PKG=""
if need_cmd apt-get; then PKG="apt"; fi
if need_cmd brew; then PKG="brew"; fi

# Install Node.js if missing
if ! need_cmd node || ! need_cmd npm; then
  info "Node.js/npm not found. Attempting to install..."
  if [ "$PKG" = "apt" ]; then
    info "Installing Node.js 20 via NodeSource (apt)..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | $SUDO bash -
    $SUDO apt-get update
    $SUDO apt-get install -y nodejs
  elif [ "$PKG" = "brew" ]; then
    info "Installing Node.js via Homebrew..."
    brew install node@20 || brew install node
  else
    err "Unsupported package manager. Please install Node.js 20+ manually: https://nodejs.org/"
    exit 1
  fi
fi

# Install Docker if missing
if ! need_cmd docker || ! need_cmd docker-compose; then
  info "Docker or docker compose not found. Attempting to install..."
  if [ "$PKG" = "apt" ]; then
    info "Installing Docker via official script..."
    curl -fsSL https://get.docker.com | $SUDO sh
    # ensure docker-compose plugin exists (Docker 20.10+ includes compose as plugin, else user can install compose separately)
  elif [ "$PKG" = "brew" ]; then
    info "Installing Docker Desktop via Homebrew Cask (macOS)..."
    brew install --cask docker
    info "Please open Docker Desktop and allow it to start before continuing."
    read -p "Press Enter after Docker Desktop is running..."
  else
    err "Unsupported package manager. Install Docker Desktop manually: https://www.docker.com/products/docker-desktop"
    exit 1
  fi
  # Add current user to docker group on Linux
  if [ "$PKG" = "apt" ]; then
    $SUDO usermod -aG docker "$(logname)" || true
    info "You may need to log out and log in again for docker group changes to apply."
  fi
fi

info "Installing npm dependencies..."
# Use npm ci when package-lock.json exists for deterministic installs, otherwise npm install
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund
else
  echo "package-lock.json not present; running npm install to create a lockfile"
  npm install --no-audit --no-fund
fi

# Prompt for admin password to hash
read -s -p "Enter admin password to hash (will not echo): " ADMIN_PASS
echo
if [ -z "$ADMIN_PASS" ]; then
  err "No admin password provided.";
  exit 1
fi

info "Generating Argon2 hash for admin password..."
ADMIN_HASH=$(node scripts/hash-password.mjs "$ADMIN_PASS") || { err "Failed to hash admin password"; exit 1; }
ADMIN_HASH=$(echo "$ADMIN_HASH" | tr -d '\r\n')

# Ensure .env exists
if [ ! -f .env ]; then
  cp .env.example .env || true
fi

# Update or append ADMIN_PASSWORD_HASH
if grep -q '^ADMIN_PASSWORD_HASH=' .env; then
  sed -i.bak "s|^ADMIN_PASSWORD_HASH=.*|ADMIN_PASSWORD_HASH=${ADMIN_HASH}|" .env
else
  echo "ADMIN_PASSWORD_HASH=${ADMIN_HASH}" >> .env
fi
info "Updated .env with ADMIN_PASSWORD_HASH"

# Start Postgres via docker compose
info "Starting Postgres via docker compose..."
docker compose up -d postgres || { err "Failed to start postgres service via docker compose"; exit 1; }

# Wait for Postgres to accept connections on 5432
info "Waiting for Postgres to accept connections (up to 60s)..."
READY=0
for i in $(seq 1 12); do
  if nc -z 127.0.0.1 5432 >/dev/null 2>&1; then
    READY=1; break
  fi
  sleep 5
done
if [ "$READY" -ne 1 ]; then
  err "Postgres did not start within expected time. Inspect docker compose logs: docker compose logs postgres"
else
  info "Postgres appears to be listening on 5432"
fi

info "Running DB migrations..."
npm run db:migrate

info "Starting server (foreground). Use Ctrl+C to stop."
npm start

# End
