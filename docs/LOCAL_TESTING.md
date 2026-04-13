# Neofy — Local Testing Guide (Windows + PowerShell)

---

## Part 1: Local Environment Setup

### Prerequisites

Install in this order:

```powershell
# 1. Ruby 3.3.x via RubyInstaller (rubyinstaller.org)
#    → Select "Add Ruby to PATH" and "Install MSYS2"
#    → After install, run: ridk install (choose option 3)

ruby --version   # → ruby 3.3.x

# 2. Node.js (already installed — v22)
node --version   # → v22.x

# 3. MySQL 8.x (mysql.com/downloads)
#    → Remember your root password

# 4. Redis for Windows (Memurai or WSL2 Redis)
#    Option A: Memurai (native Windows): memurai.com
#    Option B: WSL2: sudo apt install redis-server

# 5. Install Rails + gems
gem install bundler
cd C:\Users\Akhil\Desktop\neofy\backend
bundle install  # after rails new runs

# 6. Stripe CLI (stripe.com/docs/stripe-cli)
#    Download stripe_windows_x86_64.zip, add to PATH
stripe --version
```

---

## Part 2: Bootstrap Rails Project

```powershell
# Step 1: Create the Rails project (runs once)
cd C:\Users\Akhil\Desktop\neofy
rails new backend --api --database=mysql --skip-bundle --skip-git --force

# Step 2: Replace the generated Gemfile with our existing one (already done)
# Step 3: Install gems
cd backend
bundle install

# Step 4: Set up .env
copy .env.example .env
# Edit .env with your MySQL password and other values
```

### `.env` minimum required values for local testing:

```env
DATABASE_HOST=localhost
DATABASE_PORT=3306
DATABASE_USERNAME=root
DATABASE_PASSWORD=your_mysql_root_password
DATABASE_NAME=neofy_development

REDIS_URL=redis://localhost:6379/0

DEVISE_JWT_SECRET_KEY=dev-secret-key-minimum-32-characters-long-here
SECRET_KEY_BASE=dev-secret-key-base-minimum-64-characters-long-here

STRIPE_SECRET_KEY=sk_test_YOUR_STRIPE_TEST_KEY
STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_STRIPE_TEST_KEY
STRIPE_WEBHOOK_SECRET=whsec_get_from_stripe_cli

FRONTEND_URL=http://localhost:5173
RAILS_ENV=development
```

---

## Part 3: Database Setup

```powershell
cd C:\Users\Akhil\Desktop\neofy\backend

# Create databases
rails db:create

# Run all migrations
rails db:migrate

# Seed plans + demo data
rails db:seed
```

Expected seed output:
```
Seeding Neofy development data...
  Plans seeded: 4
  Admin: admin@neofy.com
  Owner: demo@neofy.com
  Store: Demo Fashion Store (demo.neofy.com)
  Created product: Classic White Tee (4 variants)
  Created product: Slim Fit Jeans (3 variants)
  Created product: Minimalist Cap (3 variants)
Done! 3 products, 10 variants.
Login: demo@neofy.com / password123
Store: http://demo.lvh.me:3000
```

---

## Part 4: Start All Services

Open **4 separate PowerShell windows**:

```powershell
# Window 1 — MySQL (if not running as a Windows Service)
# Usually auto-starts. Check: Get-Service -Name MySQL*

# Window 2 — Redis (Memurai)
# Usually auto-starts. Or: memurai
# Verify: redis-cli ping  → PONG

# Window 3 — Rails Server
cd C:\Users\Akhil\Desktop\neofy\backend
rails server -p 3000

# Window 4 — Sidekiq
cd C:\Users\Akhil\Desktop\neofy\backend
bundle exec sidekiq -C config/sidekiq.yml

# Window 5 — Stripe CLI (webhook forwarding)
stripe listen --forward-to localhost:3000/api/v1/webhooks/stripe
# Copy the webhook secret printed → paste into .env STRIPE_WEBHOOK_SECRET
# Then restart Rails (Window 3)

# Window 6 — Frontend (optional)
cd C:\Users\Akhil\Desktop\neofy\frontend
npm run dev
```

---

## Part 5: End-to-End Test Flow (curl / PowerShell)

### Tip: Set base URL variable
```powershell
$API = "http://localhost:3000/api/v1"
$STORE = "demo"  # subdomain
```

---

### A. Authentication

```powershell
# Register a new user
$body = '{"user":{"email":"test@example.com","password":"password123","password_confirmation":"password123","first_name":"Test","last_name":"User"}}'
Invoke-RestMethod -Uri "$API/users" -Method POST -Body $body -ContentType "application/json"

# Login
$login = Invoke-RestMethod -Uri "$API/users/sign_in" `
  -Method POST `
  -Body '{"user":{"email":"demo@neofy.com","password":"password123"}}' `
  -ContentType "application/json" `
  -ResponseHeadersVariable headers

# Extract JWT from Authorization header
$JWT = $headers.Authorization -replace "Bearer ", ""
Write-Host "JWT: $JWT"

# Test protected endpoint
Invoke-RestMethod -Uri "$API/stores" `
  -Headers @{ Authorization = "Bearer $JWT" }
```

---

### B. Store + Subdomain

```powershell
# Create a store
$storeBody = '{
  "store": {
    "name": "My Test Shop",
    "subdomain": "testshop",
    "currency": "USD",
    "timezone": "UTC"
  }
}'
$store = Invoke-RestMethod -Uri "$API/stores" `
  -Method POST `
  -Body $storeBody `
  -Headers @{ Authorization = "Bearer $JWT" } `
  -ContentType "application/json"

$STORE_ID = $store.id
Write-Host "Store ID: $STORE_ID"

# Verify subdomain works (access storefront)
Start-Process "http://testshop.lvh.me:3000"
# Should render the storefront HTML with "No products yet" or default template
```

---

### C. Products + Variants

```powershell
# Create a product with variants
$productBody = '{
  "product": {
    "title": "Test T-Shirt",
    "description": "A great test product",
    "product_type": "Apparel",
    "status": "active",
    "variants": [
      {"title": "Small / Red",  "price": "29.99", "sku": "TS-S-RED",  "inventory_quantity": 10, "position": 1},
      {"title": "Medium / Red", "price": "29.99", "sku": "TS-M-RED",  "inventory_quantity": 5,  "position": 2},
      {"title": "Large / Red",  "price": "31.99", "sku": "TS-L-RED",  "inventory_quantity": 0,  "position": 3}
    ]
  }
}'

$product = Invoke-RestMethod `
  -Uri "$API/stores/$STORE_ID/products" `
  -Method POST `
  -Body $productBody `
  -Headers @{ Authorization = "Bearer $JWT" } `
  -ContentType "application/json"

$PRODUCT_ID  = $product.id
$VARIANT_ID  = $product.variants[0].id
Write-Host "Product: $PRODUCT_ID  | Variant: $VARIANT_ID"

# Publish the product
Invoke-RestMethod `
  -Uri "$API/stores/$STORE_ID/products/$PRODUCT_ID/publish" `
  -Method PATCH `
  -Headers @{ Authorization = "Bearer $JWT" }

# Fetch products list
Invoke-RestMethod `
  -Uri "$API/stores/$STORE_ID/products" `
  -Headers @{ Authorization = "Bearer $JWT" }
```

---

### D. Checkout (Order creation + inventory deduction)

```powershell
$orderBody = "{
  `"order`": {
    `"customer`": { `"email`": `"customer@example.com`", `"first_name`": `"Jane`", `"last_name`": `"Doe`" },
    `"items`": [{ `"variant_id`": `"$VARIANT_ID`", `"quantity`": 2 }],
    `"shipping_address`": { `"address1`": `"123 Main St`", `"city`": `"New York`", `"country`": `"US`", `"zip`": `"10001`" }
  }
}"

$order = Invoke-RestMethod `
  -Uri "$API/stores/$STORE_ID/orders" `
  -Method POST `
  -Body $orderBody `
  -Headers @{ Authorization = "Bearer $JWT" } `
  -ContentType "application/json"

$ORDER_ID = $order.id
Write-Host "Order: $ORDER_ID | Status: $($order.financial_status)"

# Verify inventory was deducted (should now be 8, was 10)
Invoke-RestMethod `
  -Uri "$API/variants/$VARIANT_ID" `
  -Headers @{ Authorization = "Bearer $JWT" }
# Check: inventory_quantity should be 8
```

---

### E. Payments (Stripe)

```powershell
# Create payment intent
$intent = Invoke-RestMethod `
  -Uri "$API/stores/$STORE_ID/orders/$ORDER_ID/payment_intent" `
  -Method POST `
  -Headers @{ Authorization = "Bearer $JWT" }

Write-Host "Client Secret: $($intent.client_secret)"
Write-Host "Payment ID: $($intent.payment.id)"

# Simulate payment.succeeded via Stripe CLI (Window 5):
# stripe trigger payment_intent.succeeded
# OR use the payment intent ID:
# stripe payment_intents confirm pi_xxx --payment-method pm_card_visa

# Watch the order status update:
Invoke-RestMethod `
  -Uri "$API/stores/$STORE_ID/orders/$ORDER_ID" `
  -Headers @{ Authorization = "Bearer $JWT" }
# After webhook fires: financial_status should be "paid"
```

---

### F. Webhook Testing (Stripe CLI)

```powershell
# In the Stripe CLI window (Window 5), send test events:

# Test successful payment
stripe trigger payment_intent.succeeded

# Test failed payment
stripe trigger payment_intent.payment_failed

# Test subscription events
stripe trigger customer.subscription.created
stripe trigger invoice.paid
stripe trigger invoice.payment_failed

# Watch Rails logs (Window 3) for:
# [StripeWebhookJob] Processing payment_intent.succeeded
# [Stripe Webhook] Order #1001 marked as PAID
```

---

### G. Storefront (Theme rendering)

```powershell
# Visit in browser (subdomain must resolve to localhost via lvh.me)
# testshop.lvh.me:3000       → Product list (index template)
# testshop.lvh.me:3000/products/test-t-shirt  → Product detail

# Test with curl:
curl "http://testshop.lvh.me:3000"
curl "http://testshop.lvh.me:3000/products/test-t-shirt"
```

---

### H. Subscription / Billing

```powershell
# Get available plans
Invoke-RestMethod -Uri "$API/plans"

# NOTE: Subscription creation requires Stripe price IDs to be configured in plans.
# For testing without Stripe, verify feature gates work:

# Try creating more than 10 products (Free plan limit):
# Should get: { "errors": ["Your Free plan allows a maximum of 10 max products..."] }

# Check store dashboard
Invoke-RestMethod `
  -Uri "$API/stores/$STORE_ID/dashboard?period=30d" `
  -Headers @{ Authorization = "Bearer $JWT" }
```

---

### I. Domain Management

```powershell
# Add a custom domain (for testing — DNS won't resolve locally)
$domainBody = '{"domain": {"domain": "mystore-test.com"}}'
$domain = Invoke-RestMethod `
  -Uri "$API/stores/$STORE_ID/domains" `
  -Method POST `
  -Body $domainBody `
  -Headers @{ Authorization = "Bearer $JWT" } `
  -ContentType "application/json"

# View verification instructions
$domain.verification_instructions
# Add TXT record: neofy-verification=<token>
# Then call verify:
Invoke-RestMethod `
  -Uri "$API/stores/$STORE_ID/domains/$($domain.id)/verify" `
  -Method POST `
  -Headers @{ Authorization = "Bearer $JWT" }
```

---

## Part 6: Debugging Guide

### Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `ECONNREFUSED 3306` | MySQL not running | `Start-Service MySQL80` or start via MySQL Workbench |
| `ECONNREFUSED 6379` | Redis not running | Start Memurai or WSL Redis |
| `TenantNotSetError` | Missing store context on request | Add `?store_id=<uuid>` or use subdomain header |
| `401 Unauthorized` | JWT expired or missing | Re-login to get fresh token |
| `Missing column deleted_at` | Migration not run | `rails db:migrate` |
| `PunditNotAuthorized` | Wrong user trying to access store | Ensure token belongs to store owner |
| Sidekiq jobs not running | Sidekiq not started | Run `bundle exec sidekiq` in background window |
| Stripe webhook 400 | Wrong STRIPE_WEBHOOK_SECRET | Copy secret from Stripe CLI output to .env |

### How to Read Logs

```powershell
# Rails logs are in:
Get-Content C:\Users\Akhil\Desktop\neofy\backend\log\development.log -Wait -Tail 50

# Or in the Rails server window — search for:
# [Job]          → background job lifecycle
# [Stripe]       → payment/webhook events
# [Billing]      → subscription events
# [OrderMailer]  → email delivery
```

### Tracing a Request Flow

```
1. Incoming request hits ApplicationController
   → resolve_tenant_from_subdomain (sets Current.store)
   → authenticate_user! (sets Current.user from JWT)

2. For tenant-scoped actions:
   → require_store_context! (ensures Current.store is set)
   → Pundit authorize (checks store_owner?)

3. Service object runs:
   → Returns ServiceResult(success: true/false, object: ..., errors: [...])

4. Controller renders JSON response

5. Background jobs via Sidekiq:
   → OrderProcessingJob: email + customer stats
   → StripeWebhookJob: payment/subscription status updates
```

---

## Part 7: Performance Testing (Basic)

```powershell
# Install ApacheBench (comes with Apache HTTP Server for Windows)
# OR use PowerShell loop for basic load test

# Test product listing endpoint (20 concurrent, 100 total)
$headers = @{ Authorization = "Bearer $JWT" }
$url = "$API/stores/$STORE_ID/products"

1..20 | ForEach-Object -Parallel {
  $start = Get-Date
  Invoke-RestMethod -Uri $using:url -Headers $using:headers | Out-Null
  $elapsed = (Get-Date) - $start
  Write-Host "Request $_: $($elapsed.TotalMilliseconds)ms"
} -ThrottleLimit 5
```

**Expected performance targets:**
- Product index: < 100ms
- Checkout: < 500ms (includes locking)
- Stripe payment intent: < 1000ms (network to Stripe)
- Storefront render: < 200ms

**Slow endpoint fixes:**
- `products index` slow → check `includes(:variants)` is present ✓
- `orders index` slow → check `includes(:customer, :payment, order_items: [:variant])` ✓
- Dashboard slow → add Redis caching to `StoreDashboard` service for prod

---

## Part 8: Final Production Checklist

- [ ] **Auth working** — JWT sign_in returns token, protected routes return 401 without it
- [ ] **Multi-tenant isolation** — Store A cannot see Store B's products/orders (verify with 2 stores)
- [ ] **Checkout safe** — Order creates correctly, inventory decrements, job enqueued after commit
- [ ] **Payments working** — Payment intent returns client_secret, webhook updates order to :paid
- [ ] **Webhooks verified** — Stripe CLI events trigger correct status updates
- [ ] **Theme rendering** — `store.lvh.me:3000` renders HTML storefront
- [ ] **Domains** — Custom domain API creates + returns verification instructions
- [ ] **Billing enforced** — Free plan blocks product creation after 10 products
- [ ] **Admin panel** — `admin@neofy.com` can access `/api/v1/admin/stores`
- [ ] **Rate limiting** — 121st request in 60s returns 429
- [ ] **Seeds ran** — 4 plans, demo store, products present
- [ ] **No critical errors in logs** — No TenantNotSetError, no N+1 warnings from Bullet
- [ ] **Sidekiq processing** — Jobs visible in `http://localhost:3000/sidekiq`
