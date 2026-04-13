# Neofy — Production Deployment Guide

---

## Infrastructure Recommendation

**VPS over AWS for MVP** — simpler, predictable cost, full control.

| Provider | Tier | Specs | Cost/mo |
|---|---|---|---|
| DigitalOcean Droplet | Starter | 4 GB RAM, 2 vCPU | ~$24 |
| Hetzner CX31 | Starter | 8 GB RAM, 2 vCPU | ~$15 |
| DigitalOcean Droplet | Growth | 8 GB RAM, 4 vCPU | ~$48 |

**Move to AWS when**: > 50k orders/month, need RDS/ElastiCache, or multi-region.

**OS**: Ubuntu 22.04 LTS

---

## Part 1: First-Time Server Setup

```bash
# 1. SSH into new server
ssh root@YOUR_SERVER_IP

# 2. Run bootstrap script
curl -O https://raw.githubusercontent.com/neorixlabs/neofy/main/deploy/setup.sh
chmod +x setup.sh
./setup.sh

# 3. Set up MySQL database
mysql -u root -p < /path/to/deploy/setup_db.sql
# Enter root password, then:
# When prompted for new neofy user password → use strong password, add to .env

# 4. Create the shared .env file
mkdir -p /var/www/neofy/shared/config
cp /path/to/deploy/env.production.example /var/www/neofy/shared/config/.env
nano /var/www/neofy/shared/config/.env  # Fill in ALL values
chmod 600 /var/www/neofy/shared/config/.env
chown deploy:deploy /var/www/neofy/shared/config/.env
```

---

## Part 2: SSL Certificates

```bash
# ── Platform domain + wildcard ───────────────────────────────────────────────
# Wildcard cert requires DNS challenge (use Cloudflare DNS)
apt-get install -y python3-certbot-dns-cloudflare
pip3 install certbot-dns-cloudflare

# Create Cloudflare credentials
cat > /root/.secrets/cloudflare.ini << EOF
dns_cloudflare_api_token = YOUR_CLOUDFLARE_API_TOKEN
EOF
chmod 600 /root/.secrets/cloudflare.ini

certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
  -d neofy.com \
  -d "*.neofy.com" \
  --email admin@neofy.com \
  --agree-tos \
  --non-interactive

# ── Custom domains (per-domain cert) ─────────────────────────────────────────
# Run for each verified custom domain:
certbot certonly \
  --nginx \
  -d mystore.com \
  --email admin@neofy.com \
  --agree-tos \
  --non-interactive

# ── Auto-renew (already set up by certbot) ────────────────────────────────────
# Verify: systemctl status certbot.timer
# Manual test: certbot renew --dry-run
```

---

## Part 3: Nginx Setup

```bash
# Copy config
cp /var/www/neofy/current/deploy/nginx/neofy.conf /etc/nginx/sites-available/neofy

# Disable default site
rm -f /etc/nginx/sites-enabled/default

# Enable Neofy
ln -s /etc/nginx/sites-available/neofy /etc/nginx/sites-enabled/neofy

# Test config
nginx -t  # Must output: syntax is ok + test is successful

# Reload
systemctl reload nginx

# Copy logrotate config
cp /var/www/neofy/current/deploy/logrotate/neofy /etc/logrotate.d/neofy
```

---

## Part 4: systemd Services

```bash
# Copy service files
cp /var/www/neofy/current/deploy/systemd/neofy-web.service     /etc/systemd/system/
cp /var/www/neofy/current/deploy/systemd/neofy-sidekiq.service /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable (auto-start on reboot)
systemctl enable neofy-web
systemctl enable neofy-sidekiq

# Start
systemctl start neofy-web
systemctl start neofy-sidekiq

# Check status
systemctl status neofy-web
systemctl status neofy-sidekiq

# View live logs
journalctl -u neofy-web     -f
journalctl -u neofy-sidekiq -f
```

---

## Part 5: First Deploy

```bash
# As the 'deploy' user:
sudo -u deploy bash

# Deploy main branch
/var/www/neofy/current/deploy/deploy.sh main

# OR on first deploy (no current link yet):
cd /var/www/neofy
git clone git@github.com:neorixlabs/neofy.git releases/initial
ln -s releases/initial current

cd current/backend
bundle install --deployment --without development test
RAILS_ENV=production bundle exec rails db:create db:migrate db:seed
```

---

## Part 6: Stripe Webhook Registration

```bash
# Register your webhook endpoint in Stripe Dashboard:
# Dashboard → Developers → Webhooks → Add endpoint
#
# URL: https://neofy.com/api/v1/webhooks/stripe
#
# Events to listen for:
#   payment_intent.succeeded
#   payment_intent.payment_failed
#   customer.subscription.created
#   customer.subscription.updated
#   customer.subscription.deleted
#   invoice.paid
#   invoice.payment_failed
#
# Copy the "Signing secret" → add to .env as STRIPE_WEBHOOK_SECRET
# Restart Rails: systemctl restart neofy-web

# Verify webhook delivery:
# Stripe Dashboard → Webhooks → your endpoint → Recent deliveries
```

---

## Part 7: DNS Configuration

```
# In your DNS provider (Cloudflare recommended):

Type    Name        Value               TTL
A       @           YOUR_SERVER_IP      Auto
A       www         YOUR_SERVER_IP      Auto
A       app         YOUR_SERVER_IP      Auto
A       api         YOUR_SERVER_IP      Auto
CNAME   *           neofy.com           Auto   ← wildcard for tenant subdomains

# For custom domains (each store owner does this themselves):
CNAME   @           neofy.com           Auto   (or A record to YOUR_SERVER_IP)
TXT     @           neofy-verification=TOKEN
```

---

## Part 8: Production Validation Flow

```bash
BASE="https://api.neofy.com/api/v1"

# 1. Healthcheck
curl https://neofy.com/up
# → {"status":"ok","timestamp":"..."}

# 2. Register + Login
curl -X POST "$BASE/users" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"owner@example.com","password":"securepassword123","password_confirmation":"securepassword123","first_name":"Store","last_name":"Owner"}}'

LOGIN=$(curl -si -X POST "$BASE/users/sign_in" \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"owner@example.com","password":"securepassword123"}}')
TOKEN=$(echo "$LOGIN" | grep -i "Authorization:" | awk '{print $3}' | tr -d '\r')
echo "Token: $TOKEN"

# 3. Create store
curl -X POST "$BASE/stores" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"store":{"name":"My Shop","subdomain":"myshop","currency":"USD","timezone":"UTC"}}'

# 4. Visit storefront
curl https://myshop.neofy.com
# → HTML storefront

# 5. Create product + checkout (see LOCAL_TESTING.md for full flow)
```

---

## Part 9: Failure Scenarios

### Payment failure
```
Stripe sends: payment_intent.payment_failed
→ StripeWebhookJob processes event
→ Payments::HandleWebhookEvent#handle_payment_failed
→ payment.status = :failed
→ PaymentMailer.failed(payment).deliver_later
→ Store owner / customer notified

Recovery: customer retries via new payment intent (POST /orders/:id/payment_intent creates new intent)
```

### Webhook retry
```
Stripe retries failed webhook deliveries with exponential backoff over 72h.
Our endpoint returns 200 immediately after enqueuing.
If Sidekiq is down, webhook returns 500 → Stripe retries.
If Sidekiq processes same event twice → HandleWebhookEvent is idempotent (status_succeeded? guard).
```

### Server restart
```bash
# Systemd auto-restarts both Puma and Sidekiq on crash
# On manual restart:
systemctl restart neofy-web
systemctl restart neofy-sidekiq

# Verify recovery:
systemctl status neofy-web
curl https://neofy.com/up
```

### DB disconnect
```
ActiveRecord raises ActiveRecord::StatementInvalid or Mysql2::Error.
Puma worker crashes → systemd restarts it.
On restart: establish_connection is called fresh.
Connection pool is configured with pool: 5 per worker.

Prevention: set MySQL wait_timeout = 28800 (8h) in my.cnf
```

### Redis failure
```
If Redis is down:
  - Sidekiq cannot process jobs (jobs pile up in memory, then lost if Sidekiq restarts without persistence)
  - Rack::Attack falls back to in-memory throttle (still works, less accurate)
  - Sessions are unaffected (JWT-based, stateless)

Prevention: Redis persistence enabled (appendonly yes in setup.sh)
Recovery: sudo systemctl restart redis-server
          sudo systemctl restart neofy-sidekiq
```

---

## Part 10: Scaling Strategy

### Current architecture limits
- Single VPS handles ~500 req/s with Puma (2 workers × 5 threads)
- Sidekiq handles ~50 jobs/s on single Redis
- MySQL on same server handles ~1000 queries/s

### Scale triggers and actions

| Signal | Threshold | Action |
|---|---|---|
| CPU > 70% sustained | > 30 min | Vertical scale (double RAM/CPU) |
| DB query time p99 > 100ms | Any | Add MySQL read replica |
| Checkout latency p95 > 500ms | Any | Add 2nd Puma worker process |
| Redis memory > 1 GB | Any | Dedicated Redis server |
| Sidekiq queue depth > 1000 | Any | Add Sidekiq workers (scale horizontally) |
| > 10k orders/day | Sustained | Extract Go checkout microservice |

### Phase 2: Multi-server

```
                    ┌─ Load Balancer (Nginx/HAProxy) ─┐
                    │                                  │
              ┌─────▼─────┐                    ┌──────▼──────┐
              │  Rails #1  │                    │  Rails #2   │
              │  (Puma)    │                    │  (Puma)     │
              └─────┬──────┘                    └──────┬──────┘
                    │                                  │
              ┌─────▼──────────────────────────────────▼──────┐
              │              MySQL (Primary)                    │
              │                    ↕ replication                │
              │              MySQL (Replica) ← analytics       │
              └────────────────────────────────────────────────┘
                                   │
              ┌────────────────────▼───────────────────────────┐
              │         Redis Cluster (3 nodes)                  │
              │  Sidekiq queues + Rack::Attack + session cache   │
              └────────────────────────────────────────────────┘
```

### Phase 3: Go checkout microservice (when to extract)

**Trigger**: checkout p95 latency > 300ms AND order volume > 500/day

```
Rails API ──gRPC──► Go Checkout Service
                        1. Inventory lock (Redis distributed lock)
                        2. Reserve stock (gRPC → Rails Inventory service)
                        3. Persist order (gRPC → Rails Orders service)
                        4. Return order_id
Rails API ◄──────── { order_id, reserved: true }
```

---

## Part 11: Security Hardening Checklist

```bash
# 1. Verify HTTPS redirect works
curl -I http://neofy.com  # → 301 to https://

# 2. Check security headers
curl -I https://neofy.com | grep -i "strict\|frame\|content-type\|xss"

# 3. Verify rate limiting
for i in {1..125}; do curl -s -o /dev/null https://api.neofy.com/up; done
# The 121st request should return: HTTP/2 429

# 4. Verify JWT can't be replayed after logout
# Login → get token → logout → use same token → 401

# 5. Verify tenant isolation
# Store A's JWT cannot access Store B's products

# 6. Check no sensitive data in logs
grep -i "password\|secret\|credit" /var/www/neofy/shared/log/production.log
# Should return nothing (Lograge strips sensitive fields)

# 7. Verify webhook signature rejection
curl -X POST https://neofy.com/api/v1/webhooks/stripe \
  -H "Content-Type: application/json" \
  -d '{"type":"payment_intent.succeeded"}'
# → 400 Bad Request (missing Stripe-Signature)
```

---

## Final Production Checklist

- [ ] Server bootstrapped (Ruby, MySQL, Redis, Nginx, Certbot)
- [ ] `.env` file populated with all production values
- [ ] Database created + migrated + seeded
- [ ] SSL certificates issued for neofy.com + *.neofy.com
- [ ] Nginx config deployed + tested (`nginx -t`)
- [ ] systemd services enabled + running
- [ ] Stripe webhook registered + secret configured
- [ ] DNS A/CNAME records propagated
- [ ] `GET https://neofy.com/up` → `{"status":"ok"}`
- [ ] Storefront renders at `https://demo.neofy.com`
- [ ] Checkout flow end-to-end working
- [ ] Stripe CLI webhook test → order marked :paid
- [ ] Sidekiq dashboard accessible at `/sidekiq` (admin only)
- [ ] Rate limiting: 121st request returns 429
- [ ] No errors in `journalctl -u neofy-web`
- [ ] Logrotate configured + tested
- [ ] Sentry DSN set → test error reaches Sentry dashboard
- [ ] Monitoring alert set: CPU > 80%, disk > 80%, service crash
