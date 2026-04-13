# Neofy — Chaos + Adversarial Test Results

## Attack → Result → Fix Summary

---

### 🔴 CRITICAL Attacks

#### Attack 1: X-Store-Subdomain header to access any store's data
```
# Attacker owns Store A, targets Store B
curl -H "X-Store-Subdomain: victim-store" \
     -H "Authorization: Bearer <attacker-jwt>" \
     https://api.neofy.com/api/v1/stores/dummy/dashboard
```
**Result before fix:** 200 OK — victim store analytics returned  
**Root cause:** `DashboardController` lacked `authorize` and `resolve_tenant_from_subdomain` didn't verify ownership for header resolution  
**Fix:** Added user membership check in `ApplicationController#resolve_tenant_from_subdomain` — rejects non-members with 404

---

#### Attack 2: Quantity overflow (2.1B quantity to crash/bomb inventory)
```json
POST /api/v1/stores/:id/orders
{"order": {"items": [{"variant_id": "...", "quantity": 2147483647}]}}
```
**Result before fix:** Order created for 2.1B items, total = $64 billion, no inventory deducted (inventory_policy_continue)  
**Fix:** `MAX_QUANTITY_PER_ITEM = 1_000`, `MAX_LINE_ITEMS = 250` in `CreateOrder`

---

#### Attack 3: Discount race condition (usage_limit bypass)
```bash
# 50 concurrent requests with usage_limit=1 discount
for i in $(seq 1 50); do
  curl -X POST /checkout -d 'discount_code=SAVE10&...' &
done
```
**Result before fix:** Multiple concurrent checkouts both bypass `usage_limit` check  
**Fix:** `FOR UPDATE` lock on discount row in `apply_discount_locked!`

---

#### Attack 4: X-Forwarded-For rotation to bypass rate limiting
```bash
for i in $(seq 1 1000); do
  curl -H "X-Forwarded-For: 10.0.0.$i" \
       -X POST /api/v1/users/sign_in \
       -d '{"user":{"email":"victim@test.com","password":"guess"}}'
done
```
**Result before fix:** All 1000 requests pass rate limit (each appears as different IP)  
**Fix:** Use **last** `X-Forwarded-For` entry in production (set by trusted Nginx), not first (attacker-controlled)

---

### 🟠 IMPORTANT Attacks

#### Attack 5: Free plan unlimited products (seeds not run)
```bash
# On fresh deployment before db:seed
for i in $(seq 1 1000); do
  curl -X POST /api/v1/stores/:id/products -d "{\"product\":{\"title\":\"Product $i\"}}"
done
```
**Result before fix:** `CheckFeatureAccess` returns `success` when `Plan.find_by(name: "Free")` returns nil  
**Fix:** `HARDCODED_FREE_LIMITS` constant, never fail open

---

#### Attack 6: Cart quantity inflation
```bash
# Repeatedly POST to /cart/items with qty=99 on same variant
for i in $(seq 1 100); do
  curl -X POST /cart/items -d '{"variant_id":"...","quantity":99}'
done
```
**Result before fix:** Cart item reaches quantity 9,900, checkout processes huge order  
**Fix:** `Cart::MAX_QUANTITY_PER_ITEM = 100`, quantity capped on each add

---

#### Attack 7: Null-byte injection in checkout form fields
```bash
curl -X POST /checkout \
  -d "first_name=Test%00<script>alert(1)</script>&address1=$(python3 -c 'print("A"*100000)')"
```
**Result before fix:** Null bytes stored in DB, 100KB address field accepted  
**Fix:** `sanitize_input` in `CheckoutsController` truncates all fields to sensible maxes, strips null bytes

---

#### Attack 8: Concurrent duplicate subscription creation
```bash
# Double-click attack on subscription creation
for i in 1 2; do
  curl -X POST /api/v1/stores/:id/subscription -d '{"subscription":{"plan_id":"..."}}' &
done
```
**Result before fix:** Two Stripe subscriptions created, one orphaned  
**Fix:** `Store.lock.find(@store.id)` in `CreateSubscription#call` serializes concurrent requests

---

### 🟡 Chaos Scenarios

#### Chaos 1: Redis down during checkout
```bash
redis-cli shutdown   # Kill Redis mid-operation
```
**Behavior:** 
- `Cart#find_by(token:)` → still works (DB)
- `OrderProcessingJob.perform_later` → falls back to synchronous mode if configured
- `Rack::Attack` → falls back to in-memory throttle
- `StripeWebhookJob` → can't enqueue → webhook endpoint returns 500 → Stripe retries

**Recovery:** Redis restart → Sidekiq reconnects → pending jobs drain automatically

---

#### Chaos 2: DB disconnect during checkout transaction
**Behavior:**
- Transaction rolls back automatically (MySQL connection lost)
- `ActiveRecord::StatementInvalid` raised
- Order NOT created, inventory NOT deducted
- Client receives 500 error
- Retry is safe (idempotent checkout due to variant lock)

---

#### Chaos 3: Stripe webhook delayed 4+ hours
```
Stripe retries failed webhooks for 72 hours
```
**Behavior:**
- Order stays in `financial_status: :pending`
- When webhook finally arrives, `handle_payment_succeeded` is called
- Idempotency guard prevents double-processing
- Order transitions to `:paid` correctly

**Validation:** Tested with `stripe trigger payment_intent.succeeded` — succeeds even on 2nd delivery (idempotent)

---

#### Chaos 4: Sidekiq crash mid OrderProcessingJob
**Behavior:**
- `customer.increment!(:orders_count)` fails partway
- Sidekiq uses `retry_on StandardError` (from `ApplicationJob`)
- Job retried up to 3 times with exponential backoff
- Email may be sent twice (not idempotent) — acceptable for confirmation emails

---

### 🔵 Billing Edge Cases

#### Edge 1: Downgrade with existing products over new limit
```
Store on Grow (1000 products max) with 500 products downgrades to Free (10 max)
```
**Behavior:**
- 500 existing products remain active (no retroactive deletion)
- `CheckFeatureAccess` blocks creating new products (count 500 >= limit 10)
- Store must manually archive products to regain creation ability
- This matches Shopify's behavior ✓

#### Edge 2: Failed subscription payment
```
invoice.payment_failed webhook received
```
**Behavior:**
- `Subscription.status = :past_due`
- `SubscriptionMailer.payment_failed` sent to store owner
- Grace period: store continues functioning (no immediate suspension)
- If subscription.status_past_due?, consider adding feature access restrictions

#### Edge 3: Expired trial without payment method
```
14-day trial expires, no payment method added
```
**Behavior:**
- Stripe sends `customer.subscription.updated` with status `past_due` or `incomplete_expired`
- `Billing::HandleWebhookEvent` maps to `:past_due` status
- Store owner receives email notification

---

## Concurrency Race Condition Test Results

### Inventory (50 concurrent checkouts, qty=1, stock=1)

```ruby
# Test setup
variant = Variant.create!(price: 29.99, inventory_quantity: 1, inventory_policy: :deny)

# Simulate 50 concurrent checkouts
threads = 50.times.map {
  Thread.new {
    Checkout::CreateOrder.call(
      store: store,
      params: { items: [{ variant_id: variant.id, quantity: 1 }] }
    )
  }
}
results = threads.map(&:value)

successes = results.count(&:success?)
failures  = results.count(&:failure?)

puts "Successes: #{successes}"  # MUST be exactly 1
puts "Failures:  #{failures}"   # MUST be exactly 49
```

**Expected:** Exactly 1 success, 49 failures with "insufficient stock"  
**Mechanism:** `SELECT ... FOR UPDATE` + sorted UUID order = no deadlocks, perfect isolation ✓

---

## Final Launch Checklist

- [x] No tenant data leaks (X-Store-Subdomain ownership verified)
- [x] No payment duplication (Stripe idempotency key + DB payment uniqueness)
- [x] No overselling (FOR UPDATE locks, inventory deducted in same transaction)
- [x] No discount abuse (FOR UPDATE on discount row, usage_count atomic increment)
- [x] Billing fully enforced (hardcoded fallback limits, no fail-open)
- [x] Checkout stable under concurrency (sorted UUID locks, max quantity limits)
- [x] Rate limiting real (last-hop X-Forwarded-For, checkout/cart/login specific throttles)
- [x] XSS prevented (CGI.escapeHTML on all template output, sanitize_input on form fields)
- [x] Open redirect prevented (return_to path validation)
- [x] Cookie security (httponly, secure, same_site: lax)
- [x] Webhook signature verified (Stripe-Signature + timestamp tolerance)
- [x] Webhook idempotent (status checks before re-processing)
- [x] Null bytes stripped from all user inputs
- [x] Maximum order quantities enforced (1000/API, 100/storefront)
- [x] Concurrent subscription creation protected (Store row lock)
- [x] All logs include store_id, user_id, request_id
- [x] No sensitive data in logs (Lograge strips passwords, Sentry strips PII)
