#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Neofy — Zero-downtime deployment script
# Run as the 'deploy' user on the production server.
#
# Usage:
#   ./deploy.sh              → deploy HEAD of main branch
#   ./deploy.sh v1.2.0       → deploy specific git tag
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

APP_DIR="/var/www/neofy"
REPO_URL="git@github.com:neorixlabs/neofy.git"    # Change to your repo
BRANCH="${1:-main}"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
RELEASE_DIR="${APP_DIR}/releases/${TIMESTAMP}"
SHARED_DIR="${APP_DIR}/shared"
CURRENT_LINK="${APP_DIR}/current"
KEEP_RELEASES=5

echo "==> Deploying Neofy (${BRANCH}) at ${TIMESTAMP}"

# ── 1. Clone release ──────────────────────────────────────────────────────────
echo "--> Cloning repository"
git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${RELEASE_DIR}"

# ── 2. Link shared files ──────────────────────────────────────────────────────
echo "--> Linking shared config"
ln -sf "${SHARED_DIR}/config/.env"          "${RELEASE_DIR}/backend/.env"
ln -sf "${SHARED_DIR}/log"                  "${RELEASE_DIR}/backend/log"
ln -sf "${SHARED_DIR}/tmp/pids"             "${RELEASE_DIR}/backend/tmp/pids"
ln -sf "${SHARED_DIR}/tmp/sockets"          "${RELEASE_DIR}/backend/tmp/sockets"

# ── 3. Backend setup ─────────────────────────────────────────────────────────
echo "--> Installing gems (deployment mode — no dev/test)"
cd "${RELEASE_DIR}/backend"
bundle config set --local deployment true
bundle config set --local without 'development test'
bundle install --quiet

# ── 4. Migrate database ───────────────────────────────────────────────────────
echo "--> Running migrations"
RAILS_ENV=production bundle exec rails db:migrate

# ── 5. Frontend build ─────────────────────────────────────────────────────────
echo "--> Building frontend"
cd "${RELEASE_DIR}/frontend"
npm ci --silent
npm run build

# ── 6. Symlink current ────────────────────────────────────────────────────────
echo "--> Activating release"
ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}"

# ── 7. Restart services (zero-downtime Puma phased restart) ───────────────────
echo "--> Restarting Puma (phased restart — zero downtime)"
cd "${CURRENT_LINK}/backend"
if bundle exec pumactl -S tmp/pids/puma.state status 2>/dev/null | grep -q "started"; then
  bundle exec pumactl -S tmp/pids/puma.state phased-restart
else
  sudo systemctl restart neofy-web
fi

echo "--> Restarting Sidekiq"
sudo systemctl restart neofy-sidekiq

# ── 8. Clean up old releases ─────────────────────────────────────────────────
echo "--> Cleaning up old releases (keeping ${KEEP_RELEASES})"
ls -dt "${APP_DIR}/releases"/*/ | tail -n "+$((KEEP_RELEASES + 1))" | xargs rm -rf

echo ""
echo "✓ Deployed successfully: ${RELEASE_DIR}"
echo "  App:     $(curl -sf http://localhost:3000/up | jq -r .status 2>/dev/null || echo 'check manually')"
