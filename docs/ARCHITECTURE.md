# Neofy — System Architecture

> Shopify-like multi-tenant SaaS platform by Neorix Labs

---

## System Overview

```
                          ┌────────────────────────────────┐
                          │         NEOFY PLATFORM          │
                          └────────────┬───────────────────┘
                                       │
             ┌─────────────────────────┼─────────────────────────┐
             │                         │                          │
    ┌────────▼──────────┐   ┌─────────▼─────────┐   ┌──────────▼─────────┐
    │  React Admin SPA  │   │  Rails API Backend │   │  Public Storefront │
    │  (localhost:5173) │   │  (Puma :3000)       │   │  (HTML rendering)  │
    └────────┬──────────┘   └─────────┬─────────┘   └──────────┬─────────┘
             │                        │                          │
             └────────────────────────┴──────────────────────────┘
                                       │
                          ┌────────────▼────────────┐
                          │        Nginx             │
                          │   SSL termination         │
                          │   Wildcard + custom domain│
                          └────────────┬─────────────┘
                                       │
             ┌─────────────────────────┼─────────────────────┐
             │                         │                      │
    ┌────────▼──────────┐   ┌─────────▼──────────┐  ┌───────▼──────────┐
    │      MySQL         │   │       Redis         │  │     Sidekiq      │
    │  (Primary store)   │   │  Cache + Queues      │  │  Background Jobs │
    └───────────────────┘   └────────────────────┘  └──────────────────┘
```

---

## Multi-Tenant Architecture

**Strategy**: Shared database with `store_id` on every tenant table.

### Isolation layers:
1. **Model layer** — `TenantScoped` concern adds `default_scope { where(store_id: Current.store.id) }` to every tenant model. Raises `TenantNotSetError` if no context is set — impossible to silently leak data.
2. **Controller layer** — `resolve_tenant_from_subdomain` runs on every request, setting `Current.store` before any controller logic.
3. **Service layer** — All services accept `store:` explicitly. `TenantScoped.with_bypass` must be called intentionally for cross-tenant platform queries.

### Tenant resolution priority:
```
Request arrives
  │
  ├─1. X-Store-Subdomain header  → Store.find_by(subdomain: header)
  ├─2. Custom domain              → Domain.where(domain: host).store
  ├─3. Subdomain pattern          → Store.find_by(subdomain: "my-store")
  └─4. :store_id URL param        → current_user.stores.find(store_id)
```

---

## Request → Checkout → Payment → Webhook Flow

```
Browser
  │
  ├─POST /api/v1/stores/:id/orders ──────────────────────────────────────────┐
  │                                                                           │
  │  Checkout::CreateOrder                                                    │
  │    1. Validates items (all belong to store)                               │
  │    2. Acquires FOR UPDATE locks on variants (deadlock-safe sorted order)  │
  │    3. Checks inventory_quantity >= requested                              │
  │    4. INSERT order + order_items (price snapshot)                        │
  │    5. Decrements inventory via Inventory::UpdateInventory                 │
  │    6. Enqueues OrderProcessingJob (Sidekiq)                               │
  │    └─Returns order with financial_status: pending                         │
  │                                                                           ◄┘
  │◄──{ order: { id, order_number, total_price, ... } }
  │
  ├─POST /api/v1/stores/:id/orders/:id/payment_intent
  │
  │  Payments::CreatePaymentIntent
  │    1. Validates order is unpaid
  │    2. Finds/creates Stripe PaymentIntent (idempotency_key = order UUID)
  │    3. Creates Payment record (status: processing)
  │    └─Returns { client_secret, payment }
  │
  │◄──{ client_secret: "pi_xxx_secret_xxx" }
  │
  ├─Stripe.js confirmPayment(client_secret)
  │                                                 Stripe servers
  │                                                    │
  │                                                    ├─payment_intent.succeeded
  │                                                    │
  ├─POST /api/v1/webhooks/stripe ◄────────────────────┘
  │
  │  StripeWebhookJob (Sidekiq)
  │    → Payments::HandleWebhookEvent
  │        → payment.status = :succeeded
  │        → order.financial_status = :paid
```

---

## Database Schema (Key Tables)

```
users           ← Platform users (store owners + admins)
stores          ← Each store is a tenant (subdomain + optional custom domain)
  ↳ products    ← store_id scoped
  ↳ variants    ← store_id scoped
  ↳ customers   ← store_id scoped
  ↳ orders      ← store_id scoped
     ↳ order_items
  ↳ payments    ← store_id scoped
  ↳ themes      ← store_id scoped
     ↳ theme_templates
  ↳ domains     ← custom domains
  ↳ subscriptions ← billing subscription
plans           ← Platform-level plan definitions (Free/Basic/Grow/Advanced)
```

All tenant tables use:
- UUID primary keys
- `store_id` foreign key with DB index
- `deleted_at` soft deletes (products, variants, customers, orders)

---

## SaaS Billing

```
Store created
  → Themes::CreateDefaultTheme (after_create)
  → No subscription (free tier, 10 product limit)

Store owner upgrades
  POST /api/v1/stores/:id/subscription { plan_id, interval }
  → Billing::CreateSubscription
      → Stripe::Customer.create
      → Stripe::Subscription.create (14-day trial)
  → Email: SubscriptionMailer.activated

Stripe webhook: customer.subscription.updated
  → Billing::HandleWebhookEvent#handle_subscription_updated
      → Subscription.status = stripe status
      → Store.plan = plan name (denormalized for quick access)

Stripe webhook: invoice.payment_failed
  → Subscription.status = :past_due
  → Email: SubscriptionMailer.payment_failed
```

---

## Feature Gates

```ruby
# In ProductsController#create:
result = Billing::CheckFeatureAccess.call(
  store:         Current.store,
  feature:       :max_products,
  current_count: Current.store.products.count
)
return render_error(result.errors) if result.failure?
```

| Feature          | Free | Basic | Grow  | Advanced  |
|------------------|------|-------|-------|-----------|
| max_products     | 10   | 100   | 1000  | Unlimited |
| max_staff        | 1    | 3     | 10    | Unlimited |
| custom_domain    | ✗    | ✓     | ✓     | ✓         |
| analytics        | ✗    | ✗     | ✓     | ✓         |
| priority_support | ✗    | ✗     | ✗     | ✓         |
| api_rate_limit   | 100  | 300   | 1000  | Unlimited |

---

## Rate Limiting (Rack::Attack)

| Rule                        | Limit      | Window |
|-----------------------------|-----------|--------|
| API requests by IP          | 120 req   | 60s    |
| API requests by JWT token   | 300 req   | 60s    |
| Login attempts (IP+email)   | 5 attempts| 20s    |
| Storefront requests by IP   | 60 req    | 60s    |

Backed by Redis for distributed rate limiting across multiple Puma workers.

---

## Scaling Strategy

### Current: Modular Monolith (Rails)
- All services co-located in `/app/services`
- Single Puma process + Sidekiq workers
- MySQL + Redis on the same/adjacent server
- Suitable for: 0–100k orders/month

### Phase 2: Extract Checkout to Go (when to trigger)
Trigger when checkout latency > 200ms p95 or concurrency > 50 req/sec.

```
Rails Monolith                Go Checkout Service
      │                               │
      │  POST /api/v1/checkout ───────►
      │                          1. Validate items (gRPC to Rails catalog)
      │                          2. Acquire Redis distributed locks
      │                          3. Deduct inventory (gRPC to Rails)
      │                          4. Create order (gRPC to Rails)
      │◄──── { order_id, total } ──────
```

Communication: **gRPC** (strongly typed, low latency, bi-directional streaming for inventory events)

### Phase 3: Service Mesh
```
/services/
  checkout/     (Go) — high-throughput order processing
  inventory/    (Go) — real-time stock management
  search/       (Go + Elasticsearch) — product search
  notifications/(Node.js) — email, webhooks, push
```

### Database Scaling
1. Read replicas for analytics queries (ActiveRecord `connects_to`)
2. Schema-per-tenant for enterprise customers (extract via `apartment` gem)
3. Database-per-tenant for highest isolation tier (future)

---

## Security Model

| Layer        | Mechanism                                      |
|--------------|------------------------------------------------|
| Transport    | HTTPS via Nginx (cert per domain)              |
| Auth         | Devise + JWT (JTI-based revocation)            |
| Authorization| Pundit policies (store_owner? check)           |
| Tenant isolation | TenantScoped default_scope + TenantNotSetError |
| Payments     | Stripe webhook signature verification           |
| Rate limiting| Rack::Attack (Redis-backed)                    |
| Input safety | Strong params (`permit`) + ActiveRecord validations |
| Headers      | X-Frame-Options, nosniff, XSS-Protection       |
| Monitoring   | Sentry (error tracking) + Lograge (JSON logs)  |

---

## Environment Variables Reference

See `backend/.env.example` for the complete list.

Key production variables:
- `STRIPE_SECRET_KEY` + `STRIPE_WEBHOOK_SECRET`
- `DEVISE_JWT_SECRET_KEY`
- `REDIS_URL`
- `SENTRY_DSN`
- `SMTP_*` for email delivery
- `TRUSTED_PROXIES` for Nginx IP
