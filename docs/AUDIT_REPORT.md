# Neofy — Production Audit Report

## Issues Found & Fixed

### 🔴 CRITICAL (Fixed)

| # | Issue | Fix |
|---|---|---|
| 1 | **Open redirect** — `return_to` param accepted external URLs in customer login | Validate starts with `/`, block `//` protocol-relative |
| 2 | **Discount silently ignored** — `CreateOrder` hardcoded `total_discounts: 0`, never applied code | `apply_discount_locked!` with FOR UPDATE, applies amount to order total |
| 3 | **Discount race condition** — concurrent checkouts both pass `usage_limit` check | FOR UPDATE row lock on discount before validation |

### 🟠 IMPORTANT (Fixed)

| # | Issue | Fix |
|---|---|---|
| 4 | **Cookies missing `secure:` flag** — cart/customer tokens sent over HTTP in prod | Added `secure: Rails.env.production?, same_site: :lax` |
| 5 | **Cart created on every page load** — `global_context → cart_item_count → find_or_create_cart` writes DB on every render | `existing_cart` (read-only), `create_cart!` only on first add |
| 6 | **XSS in error page** — store name interpolated unescaped in `<title>` and `<h1>` | `CGI.escapeHTML` on all dynamic values in error HTML |
| 7 | **N+1 in shipping rates** — `includes(:shipping_rates)` defeated by `.where(active: true)` in Ruby loop | Filter with `select(&:active?)` on already-loaded association |
| 8 | **Bare `rescue` swallows all errors** in `cart_item_count` | Rescue specific DB errors only |

### 🟡 CODE BUGS (Fixed)

| # | Issue | Fix |
|---|---|---|
| 9 | **`order_detail_context` dead code** — first `o.order_items.map` result discarded, items loaded twice | Consolidate into single `items` variable |
| 10 | **`orders_context` N+1** — `o.order_items.size` on every order row triggers extra query | Use `o.items_count` (already-loaded `order_items.size`) |
| 11 | **`Cart#total_price` Ruby loop** — loads all cart_items into memory for sum | SQL `SUM('price * quantity')` |

---

## End-to-End Test Flow

### Prerequisites

```powershell
# Start all services (4 terminals)
cd C:\Users\Akhil\Desktop\neofy\backend
rails db:create db:migrate db:seed  # one-time
rails server                         # terminal 1
bundle exec sidekiq -C config/sidekiq.yml  # terminal 2
stripe listen --forward-to localhost:3000/api/v1/webhooks/stripe  # terminal 3
cd ..\frontend && npm run dev        # terminal 4

# Copy the Stripe webhook secret to .env: STRIPE_WEBHOOK_SECRET=whsec_...
```

---

### Step 1: Register + Login

```powershell
$API = "http://localhost:3000/api/v1"

# Register
Invoke-RestMethod -Uri "$API/users" -Method POST `
  -ContentType "application/json" `
  -Body '{"user":{"email":"owner@test.com","password":"password123","password_confirmation":"password123","first_name":"Store","last_name":"Owner"}}'

# Login
$resp = Invoke-WebRequest -Uri "$API/users/sign_in" -Method POST `
  -ContentType "application/json" `
  -Body '{"user":{"email":"owner@test.com","password":"password123"}}'
$JWT = ($resp.Headers["Authorization"] -replace "Bearer ","").Trim()
Write-Host "JWT: $JWT"
```

Expected: `confirmed_at` set (seeds bypass confirmation), JWT in Authorization header.

---

### Step 2: Create Store

```powershell
$store = Invoke-RestMethod -Uri "$API/stores" -Method POST `
  -Headers @{Authorization="Bearer $JWT"} `
  -ContentType "application/json" `
  -Body '{"store":{"name":"Test Shop","subdomain":"testshop","currency":"USD","timezone":"UTC"}}'

$STORE_ID = $store.id
Write-Host "Store: $STORE_ID"
```

Expected: Store created. Default theme auto-provisioned with 9 templates.

---

### Step 3: Add Product + Variant

```powershell
$product = Invoke-RestMethod -Uri "$API/stores/$STORE_ID/products" -Method POST `
  -Headers @{Authorization="Bearer $JWT"} `
  -ContentType "application/json" `
  -Body '{
    "product":{
      "title":"Blue T-Shirt",
      "status":"active",
      "variants":[
        {"title":"Small","price":"29.99","sku":"BTS-S","inventory_quantity":10,"position":1},
        {"title":"Medium","price":"29.99","sku":"BTS-M","inventory_quantity":5,"position":2}
      ]
    }
  }'

$VARIANT_ID = $product.variants[0].id
Write-Host "Variant: $VARIANT_ID | Stock: $($product.variants[0].inventory_quantity)"

# Publish product
Invoke-RestMethod -Uri "$API/stores/$STORE_ID/products/$($product.id)/publish" `
  -Method PATCH -Headers @{Authorization="Bearer $JWT"}
```

Expected: Product active, inventory = 10 for Small.

---

### Step 4: Storefront + Cart

```powershell
# Open browser
Start-Process "http://testshop.lvh.me:3000"
# → Should render index page with product

# Add to cart via JS console in browser:
# NeofyCart.add('<variant_id>', 2)

# Or via curl:
curl -X POST "http://testshop.lvh.me:3000/cart/items" `
  -H "Content-Type: application/json" `
  -c cookies.txt -b cookies.txt `
  -d "{\"variant_id\":\"$VARIANT_ID\",\"quantity\":2}"
```

Expected: Cart item added, count = 2.

---

### Step 5: Checkout

```powershell
# POST /checkout
$checkout = curl -X POST "http://testshop.lvh.me:3000/checkout" `
  -H "Content-Type: application/json" `
  -c cookies.txt -b cookies.txt `
  -d '{
    "email":"customer@test.com",
    "first_name":"Jane","last_name":"Doe",
    "address1":"123 Main St","city":"New York",
    "country":"US","zip":"10001"
  }' | ConvertFrom-Json

$ORDER_ID = $checkout.order_id
$CLIENT_SECRET = $checkout.client_secret
Write-Host "Order: $ORDER_ID | Secret: $CLIENT_SECRET"
```

Expected: Order created (financial_status: pending), client_secret returned.

---

### Step 6: Complete Stripe Payment (Test Mode)

```powershell
# Use Stripe CLI to confirm the PaymentIntent
stripe payment_intents confirm $($checkout | ConvertFrom-Json | Select -ExpandProperty payment_intent_id) `
  --payment-method pm_card_visa

# OR trigger webhook manually:
stripe trigger payment_intent.succeeded
```

Expected (from Stripe CLI in terminal 3):
```
→ payment_intent.succeeded [evt_xxx] → 200 OK
```

---

### Step 7: Verify Order Updated

```powershell
$order = Invoke-RestMethod -Uri "$API/stores/$STORE_ID/orders/$ORDER_ID" `
  -Headers @{Authorization="Bearer $JWT"}
Write-Host "Financial status: $($order.financial_status)"
# Expected: "paid"

# Verify inventory deducted
Invoke-RestMethod -Uri "$API/variants/$VARIANT_ID" -Headers @{Authorization="Bearer $JWT"}
# Expected: inventory_quantity = 8 (was 10, ordered 2)
```

---

### Step 8: Email Verification

```powershell
# Check Sidekiq processed the email job:
# Open http://localhost:3000/sidekiq (login as admin@neofy.com)
# → Jobs processed: 2 (OrderProcessingJob + ActionMailer)

# In development, check Rails log for:
# [OrderMailer] Delivered confirmation to customer@test.com
```

---

### Step 9: Customer Account

```powershell
# Register storefront customer account
curl -X POST "http://testshop.lvh.me:3000/account/register" `
  -c cookies.txt -b cookies.txt `
  -d "email=customer@test.com&password=password123&first_name=Jane&last_name=Doe"

# Login
curl -X POST "http://testshop.lvh.me:3000/account/login" `
  -c cookies.txt -b cookies.txt `
  -d "email=customer@test.com&password=password123"

# View account
curl "http://testshop.lvh.me:3000/account" -c cookies.txt -b cookies.txt
# → HTML showing recent orders
```

---

### Step 10: Discount Code Flow

```powershell
# Create discount via admin API
Invoke-RestMethod -Uri "$API/stores/$STORE_ID/discounts" -Method POST `
  -Headers @{Authorization="Bearer $JWT"} `
  -ContentType "application/json" `
  -Body '{"discount":{"code":"SAVE10","discount_type":"percentage","value":10,"active":true}}'

# Validate code
Invoke-RestMethod -Uri "$API/stores/$STORE_ID/discounts/validate_code" -Method POST `
  -Headers @{Authorization="Bearer $JWT"} `
  -ContentType "application/json" `
  -Body "{\"code\":\"SAVE10\",\"order_total\":59.98}"
# Expected: { valid: true, discount_amount: "6.00" }

# Apply at checkout: add discount_code to checkout POST body
```

---

## Failure Scenario Tests

### Concurrent checkout (inventory race condition test)

```powershell
# Pre-condition: product with inventory_quantity = 1

# Run 5 concurrent checkouts for quantity=1 in PowerShell:
1..5 | ForEach-Object -Parallel {
  Invoke-RestMethod -Uri "http://testshop.lvh.me:3000/checkout" -Method POST `
    -ContentType "application/json" `
    -c cookies.txt -b cookies.txt `
    -Body '{"email":"test@t.com","quantity":1,...}'
} -ThrottleLimit 5

# Expected: exactly 1 succeeds, 4 fail with "insufficient stock"
# This is guaranteed by the FOR UPDATE lock in validate_and_lock_line_items!
```

### Discount race condition test

```powershell
# Create discount with usage_limit = 1
# Run 5 concurrent checkouts with the same discount code
# Expected: exactly 1 applies discount, 4 fail with "Discount code is invalid"
# Guaranteed by apply_discount_locked! FOR UPDATE lock
```

### Payment failure

```powershell
# Create order, get client_secret, then trigger failure:
stripe trigger payment_intent.payment_failed
# Expected:
# - payment.status → :failed
# - order.financial_status remains :pending (not updated to failed)
# - Rails log: [Stripe Webhook] Payment failed for order #1001

# Retry: POST /orders/:id/payment_intent again
# Expected: new payment intent created (rechargeable? = true)
```

### Webhook retry safety

```powershell
# Send same webhook event twice (Stripe delivers duplicates)
stripe trigger payment_intent.succeeded  # first delivery
stripe trigger payment_intent.succeeded  # duplicate

# Expected: idempotency guard in HandleWebhookEvent prevents double-processing
# Log: "Payment already succeeded — skipping duplicate"
```

---

## Production Security Checklist

- [x] Open redirect prevented (return_to validation)
- [x] Discount applied server-side only (never trust client total)
- [x] Discount usage_limit race condition prevented (FOR UPDATE lock)
- [x] Cart + customer cookies have `secure:`, `httponly:`, `same_site: :lax`
- [x] Cart NOT created on every page load (read-only default)
- [x] XSS prevented in storefront error pages (CGI.escapeHTML)
- [x] Shipping rate N+1 fixed
- [x] Webhook signature verified (Stripe-Signature header)
- [x] Payments idempotent (Stripe idempotency_key = order UUID)
- [x] TenantScoped raises on bypass (no silent data leaks)
- [x] SoftDeletable uses unscope(where:) not unscoped (critical tenant fix)
- [x] JWT revocation via JTI (Devise-JWT)
- [x] Customer passwords hashed via BCrypt (has_secure_password)
- [x] Rate limiting active (Rack::Attack — 120/min IP, 300/min token)
- [x] Security headers set (X-Frame-Options DENY, nosniff, XSS-Protection)
- [x] Lograge JSON logs include store_id, user_id, request_id
- [x] Sentry configured (production/staging, PII-safe)
- [x] All critical flows in DB transactions
- [x] Inventory locked with FOR UPDATE (deadlock-safe sorted order)
- [x] OrderProcessingJob enqueued after transaction commit
- [x] Fraud detection on every order (velocity, disposable email, failed payments)
