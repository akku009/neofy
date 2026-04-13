#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Neofy — Ubuntu 22.04 LTS Server Bootstrap Script
# Run once on a fresh VPS as root or a sudo user.
#
# Infrastructure choice: VPS (DigitalOcean / Hetzner / Vultr) over AWS for MVP
#   Reasons: simpler ops, predictable cost (~$20-40/mo), full control,
#   no hidden costs. Upgrade to AWS when you need managed services (RDS, ElastiCache).
#
# Recommended: 4 GB RAM, 2 vCPU, 80 GB SSD (scales to 8 GB easily)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

APP_NAME="neofy"
APP_USER="deploy"
APP_DIR="/var/www/${APP_NAME}"
RUBY_VERSION="3.3.0"
NODE_VERSION="22"

echo "==> [1/10] System update"
apt-get update -qq && apt-get upgrade -y -qq

echo "==> [2/10] Install base dependencies"
apt-get install -y -qq \
  git curl wget gnupg2 ca-certificates \
  build-essential libssl-dev libreadline-dev zlib1g-dev \
  libffi-dev libyaml-dev libgdbm-dev libncurses5-dev \
  libmysqlclient-dev pkg-config \
  imagemagick libmagickwand-dev \
  cron logrotate fail2ban ufw

# ── Nginx ─────────────────────────────────────────────────────────────────────
echo "==> [3/10] Install Nginx"
apt-get install -y -qq nginx
systemctl enable nginx

# ── MySQL 8.x ─────────────────────────────────────────────────────────────────
echo "==> [4/10] Install MySQL 8"
apt-get install -y -qq mysql-server
systemctl enable mysql
# Secure MySQL (set root password, remove anon users, etc.)
# Run interactively: mysql_secure_installation

# ── Redis ─────────────────────────────────────────────────────────────────────
echo "==> [5/10] Install Redis"
apt-get install -y -qq redis-server
# Bind to localhost only (never expose Redis publicly)
sed -i 's/^bind .*/bind 127.0.0.1/' /etc/redis/redis.conf
# Enable persistence for Sidekiq reliability
sed -i 's/^# *appendonly no/appendonly yes/' /etc/redis/redis.conf
systemctl enable redis-server
systemctl restart redis-server

# ── Node.js ───────────────────────────────────────────────────────────────────
echo "==> [6/10] Install Node.js ${NODE_VERSION}"
curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash -
apt-get install -y -qq nodejs

# ── rbenv + Ruby ──────────────────────────────────────────────────────────────
echo "==> [7/10] Create deploy user + install Ruby ${RUBY_VERSION}"
if ! id -u "${APP_USER}" &>/dev/null; then
  useradd -m -s /bin/bash "${APP_USER}"
fi

sudo -u "${APP_USER}" bash <<RBENV_SETUP
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv
  echo 'export PATH="\$HOME/.rbenv/bin:\$PATH"' >> ~/.bashrc
  echo 'eval "\$(rbenv init -)"' >> ~/.bashrc
  git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
  source ~/.bashrc
  rbenv install ${RUBY_VERSION}
  rbenv global ${RUBY_VERSION}
  gem install bundler --no-document
RBENV_SETUP

# ── App directory ─────────────────────────────────────────────────────────────
echo "==> [8/10] Create app directory structure"
mkdir -p "${APP_DIR}/shared/"{config,log,tmp/pids,tmp/sockets,public/system}
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"

# ── Firewall ─────────────────────────────────────────────────────────────────
echo "==> [9/10] Configure firewall (UFW)"
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw --force enable

# ── Certbot (Let's Encrypt) ────────────────────────────────────────────────────
echo "==> [10/10] Install Certbot"
apt-get install -y -qq certbot python3-certbot-nginx

echo ""
echo "✓ Server bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Create MySQL DB + user: mysql -u root -p < /path/to/setup_db.sql"
echo "  2. Deploy app:             sudo -u ${APP_USER} /var/www/neofy/current/deploy/deploy.sh"
echo "  3. Configure Nginx:        cp deploy/nginx/neofy.conf /etc/nginx/sites-available/neofy"
echo "  4. Obtain SSL:             certbot --nginx -d neofy.com -d *.neofy.com"
echo "  5. Enable services:        systemctl enable neofy-web neofy-sidekiq"
