module Themes
  class CreateDefaultTheme < ApplicationService
    def initialize(store:)
      @store = store
    end

    def call
      theme = TenantScoped.with_bypass do
        Theme.create!(store: @store, name: "Neofy Default", active: true)
      end

      DEFAULT_TEMPLATES.each do |attrs|
        theme.templates.create!(attrs)
      end

      success(theme)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    rescue => e
      Rails.logger.error("[Themes::CreateDefaultTheme] #{e.message}")
      failure(e.message)
    end

    private

    DEFAULT_LAYOUT = <<~HTML.freeze
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="description" content="{{ store.name }} — Shop online">
        <meta property="og:site_name" content="{{ store.name }}">
        <title>{{ page_title }} | {{ store.name }}</title>
        <link rel="canonical" href="{{ canonical_url }}">
        <style>
          *, *::before, *::after { box-sizing: border-box; }
          body { font-family: system-ui, -apple-system, sans-serif; margin: 0; background: #f9fafb; color: #111827; }
          .container { max-width: 1200px; margin: 0 auto; padding: 0 24px; }
          header { background: #fff; border-bottom: 1px solid #e5e7eb; padding: 16px 0; }
          header .inner { display: flex; align-items: center; justify-content: space-between; max-width: 1200px; margin: 0 auto; padding: 0 24px; }
          header .logo { text-decoration: none; color: #111827; font-weight: 700; font-size: 18px; }
          header nav { display: flex; align-items: center; gap: 20px; }
          header nav a { font-size: 14px; color: #6b7280; text-decoration: none; }
          header nav a:hover { color: #111827; }
          .cart-badge { background: #111827; color: #fff; border-radius: 20px; padding: 4px 12px; font-size: 13px; font-weight: 600; }
          main { padding: 40px 0; }
          footer { border-top: 1px solid #e5e7eb; padding: 24px 0; text-align: center; color: #9ca3af; font-size: 13px; margin-top: 60px; }
          .btn { display: inline-block; background: #111827; color: #fff; padding: 10px 24px; border-radius: 8px; text-decoration: none; font-size: 14px; font-weight: 600; border: none; cursor: pointer; }
          .btn:hover { background: #374151; }
          .btn-outline { background: transparent; color: #111827; border: 1px solid #d1d5db; }
          input, select, textarea { width: 100%; padding: 10px 12px; border: 1px solid #d1d5db; border-radius: 8px; font-size: 14px; margin-bottom: 12px; }
          input:focus, select:focus { outline: none; border-color: #111827; }
          .alert-error { background: #fef2f2; color: #991b1b; padding: 12px; border-radius: 8px; margin-bottom: 16px; }
          .alert-success { background: #f0fdf4; color: #166534; padding: 12px; border-radius: 8px; margin-bottom: 16px; }
        </style>
        <script>
          // Cart API helper — tiny vanilla JS for cart operations
          window.NeofyCart = {
            async add(variantId, quantity = 1) {
              const r = await fetch('/cart/items', { method: 'POST',
                headers: { 'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest' },
                body: JSON.stringify({ variant_id: variantId, quantity }) });
              const d = await r.json();
              document.querySelectorAll('.cart-count').forEach(el => el.textContent = d.count);
              return d;
            },
            async remove(variantId) {
              const r = await fetch('/cart/items/' + variantId, { method: 'DELETE',
                headers: { 'X-Requested-With': 'XMLHttpRequest' } });
              return r.json();
            }
          };
        </script>
      </head>
      <body>
        <header>
          <div class="inner">
            <a href="/" class="logo">{{ store.name }}</a>
            <nav>
              <a href="/">Home</a>
              <a href="/account">Account</a>
              <a href="/cart" class="cart-badge">Cart <span class="cart-count">{{ cart_count }}</span></a>
            </nav>
          </div>
        </header>
        <main class="container">
          {{ content_for_layout }}
        </main>
        <footer>
          <div class="container">
            &copy; {{ store.name }} &mdash; Powered by Neofy
          </div>
        </footer>
      </body>
      </html>
    HTML

    DEFAULT_INDEX = <<~HTML.freeze
      <div style="margin-bottom: 32px;">
        <h1 style="font-size: 32px; font-weight: 700; margin: 0 0 8px;">Welcome to {{ store.name }}</h1>
        <p style="color: #6b7280; font-size: 16px;">Browse our collection below.</p>
      </div>

      <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 24px;">
        {% for product in products %}
        <div style="background: #fff; border: 1px solid #e5e7eb; border-radius: 12px; overflow: hidden;">
          <div style="padding: 20px;">
            <h2 style="font-size: 16px; font-weight: 600; margin: 0 0 8px;">{{ product.title }}</h2>
            <p style="color: #6b7280; font-size: 13px; margin: 0 0 12px;">{{ product.vendor }}</p>
            <p style="font-size: 18px; font-weight: 700; margin: 0 0 12px;">{{ store.currency }} {{ product.price }}</p>
            {% if product.in_stock %}
            <span style="background: #d1fae5; color: #065f46; padding: 2px 10px; border-radius: 20px; font-size: 12px; font-weight: 500;">In Stock</span>
            {% endif %}
            {% if !product.in_stock %}
            <span style="background: #fee2e2; color: #991b1b; padding: 2px 10px; border-radius: 20px; font-size: 12px; font-weight: 500;">Out of Stock</span>
            {% endif %}
            <div style="margin-top: 16px;">
              <a href="/products/{{ product.handle }}"
                 style="display: inline-block; background: #111827; color: #fff; padding: 8px 20px; border-radius: 8px; text-decoration: none; font-size: 14px; font-weight: 500;">
                View Product
              </a>
            </div>
          </div>
        </div>
        {% endfor %}
      </div>
    HTML

    DEFAULT_PRODUCT = <<~HTML.freeze
      <div style="max-width: 760px;">
        <p style="margin: 0 0 24px;">
          <a href="/" style="color: #6b7280; text-decoration: none; font-size: 14px;">&larr; Back to store</a>
        </p>

        <h1 style="font-size: 28px; font-weight: 700; margin: 0 0 8px;">{{ product.title }}</h1>

        {% if product.vendor %}
        <p style="color: #6b7280; font-size: 14px; margin: 0 0 16px;">by {{ product.vendor }}</p>
        {% endif %}

        <p style="font-size: 24px; font-weight: 700; margin: 0 0 20px;">{{ store.currency }} {{ product.price }}</p>

        {% if product.in_stock %}
        <p style="color: #059669; font-weight: 500; margin: 0 0 20px;">&#10003; In Stock</p>
        {% endif %}
        {% if !product.in_stock %}
        <p style="color: #dc2626; font-weight: 500; margin: 0 0 20px;">&#10007; Out of Stock</p>
        {% endif %}

        <p style="color: #374151; line-height: 1.6; margin: 0 0 32px;">{{ product.description }}</p>

        <h3 style="font-size: 16px; font-weight: 600; margin: 0 0 12px;">Available Variants</h3>
        <div style="display: flex; flex-direction: column; gap: 10px;">
          {% for variant in variants %}
          <div style="background: #fff; border: 1px solid #e5e7eb; border-radius: 10px; padding: 14px 18px; display: flex; justify-content: space-between; align-items: center;">
            <div>
              <span style="font-weight: 500;">{{ variant.title }}</span>
              {% if variant.sku %}
              <span style="color: #9ca3af; font-size: 12px; margin-left: 8px;">SKU: {{ variant.sku }}</span>
              {% endif %}
            </div>
            <div style="display: flex; align-items: center; gap: 12px;">
              <span style="font-weight: 600;">{{ store.currency }} {{ variant.price }}</span>
              {% if variant.in_stock %}
              <span style="background: #d1fae5; color: #065f46; padding: 2px 8px; border-radius: 20px; font-size: 12px;">Available</span>
              {% endif %}
              {% if !variant.in_stock %}
              <span style="background: #f3f4f6; color: #6b7280; padding: 2px 8px; border-radius: 20px; font-size: 12px;">Sold Out</span>
              {% endif %}
            </div>
          </div>
          {% endfor %}
        </div>
      </div>
    HTML

    DEFAULT_CART = <<~HTML.freeze
      <h1 style="font-size:24px;font-weight:700;margin:0 0 24px">Your Cart</h1>
      {% if cart.items_count == "0" %}
        <p style="color:#6b7280">Your cart is empty. <a href="/" style="color:#111827">Continue shopping →</a></p>
      {% endif %}
      {% if !cart.items_count == "0" %}
        <div style="display:flex;flex-direction:column;gap:12px;margin-bottom:24px">
          {% for item in cart.items %}
          <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:16px;display:flex;justify-content:space-between;align-items:center">
            <div>
              <p style="font-weight:600;margin:0">{{ item.title }}</p>
              <p style="color:#6b7280;font-size:13px;margin:4px 0">{{ item.variant_title }}</p>
              <p style="margin:4px 0">{{ store.currency }} {{ item.price }} x {{ item.quantity }}</p>
            </div>
            <div style="text-align:right">
              <p style="font-weight:700;margin:0">{{ store.currency }} {{ item.line_total }}</p>
              <button onclick="NeofyCart.remove('{{ item.variant_id }}').then(()=>location.reload())"
                style="color:#dc2626;background:none;border:none;cursor:pointer;font-size:12px;margin-top:8px">Remove</button>
            </div>
          </div>
          {% endfor %}
        </div>
        <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:20px;max-width:360px;margin-left:auto">
          <div style="display:flex;justify-content:space-between;font-size:18px;font-weight:700;margin-bottom:16px">
            <span>Total</span><span>{{ store.currency }} {{ cart.total }}</span>
          </div>
          <a href="/checkout" class="btn" style="width:100%;text-align:center;display:block">Proceed to Checkout</a>
        </div>
      {% endif %}
    HTML

    DEFAULT_CHECKOUT = <<~HTML.freeze
      <div style="max-width:680px;margin:0 auto">
        <h1 style="font-size:24px;font-weight:700;margin:0 0 24px">Checkout</h1>
        <form method="POST" action="/checkout" id="checkout-form">
          <input type="hidden" name="authenticity_token" value="">
          <h3 style="font-size:16px;font-weight:600;margin:0 0 12px">Contact Information</h3>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
            <input type="text"  name="first_name" placeholder="First name" required>
            <input type="text"  name="last_name"  placeholder="Last name"  required>
          </div>
          <input type="email" name="email" placeholder="Email address" required>
          <h3 style="font-size:16px;font-weight:600;margin:16px 0 12px">Shipping Address</h3>
          <input type="text"  name="address1" placeholder="Address" required>
          <input type="text"  name="address2" placeholder="Apartment, suite, etc. (optional)">
          <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px">
            <input type="text"  name="city"     placeholder="City"    required>
            <input type="text"  name="province" placeholder="State">
            <input type="text"  name="zip"      placeholder="ZIP"     required>
          </div>
          <input type="text"  name="country"  placeholder="Country (e.g. US)" required value="US">
          <input type="text"  name="discount_code" placeholder="Discount code (optional)">
          <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:20px;margin:20px 0">
            <div style="display:flex;justify-content:space-between;font-size:18px;font-weight:700">
              <span>Order Total</span><span>{{ store.currency }} {{ cart.total }}</span>
            </div>
          </div>
          <button type="button" class="btn" style="width:100%" id="pay-btn">Continue to Payment</button>
        </form>
        <div id="payment-section" style="display:none;margin-top:20px">
          <h3 style="font-size:16px;font-weight:600;margin:0 0 12px">Payment</h3>
          <div id="payment-element"></div>
          <button type="button" class="btn" style="width:100%;margin-top:16px" id="confirm-pay-btn">Pay Now</button>
        </div>
        <script src="https://js.stripe.com/v3/"></script>
        <script>
          document.getElementById('pay-btn').addEventListener('click', async () => {
            const form = document.getElementById('checkout-form');
            const data = new FormData(form);
            const res = await fetch('/checkout', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': document.querySelector('[name=authenticity_token]').value },
              body: JSON.stringify(Object.fromEntries(data))
            });
            const { client_secret, order_id } = await res.json();
            if (!client_secret) return alert('Checkout failed');
            const stripe = Stripe('{{ store.stripe_publishable_key }}');
            const elements = stripe.elements({ clientSecret: client_secret });
            const paymentEl = elements.create('payment');
            paymentEl.mount('#payment-element');
            document.getElementById('payment-section').style.display = 'block';
            document.getElementById('pay-btn').style.display = 'none';
            document.getElementById('confirm-pay-btn').addEventListener('click', async () => {
              const { error } = await stripe.confirmPayment({
                elements, confirmParams: { return_url: window.location.origin + '/checkout/success?order_id=' + order_id }
              });
              if (error) alert(error.message);
            });
          });
        </script>
      </div>
    HTML

    DEFAULT_ORDER_CONFIRMATION = <<~HTML.freeze
      <div style="max-width:600px;margin:0 auto;text-align:center;padding:40px 0">
        <div style="font-size:48px;margin-bottom:16px">&#10003;</div>
        <h1 style="font-size:28px;font-weight:700;margin:0 0 8px">Order Confirmed!</h1>
        <p style="color:#6b7280;margin:0 0 24px">Thank you for your order, {{ order.email }}.</p>
        <div style="background:#fff;border:1px solid #e5e7eb;border-radius:12px;padding:24px;text-align:left;margin-bottom:24px">
          <div style="display:flex;justify-content:space-between;margin-bottom:8px">
            <span style="color:#6b7280">Order Number</span><strong>{{ order.order_number }}</strong>
          </div>
          <div style="display:flex;justify-content:space-between;margin-bottom:8px">
            <span style="color:#6b7280">Total</span><strong>{{ order.currency }} {{ order.total_price }}</strong>
          </div>
          <div style="display:flex;justify-content:space-between">
            <span style="color:#6b7280">Status</span><strong>{{ order.financial_status }}</strong>
          </div>
        </div>
        <a href="/account/orders" class="btn">View My Orders</a>
        <a href="/" class="btn btn-outline" style="margin-left:12px">Continue Shopping</a>
      </div>
    HTML

    DEFAULT_CUSTOMER_LOGIN = <<~HTML.freeze
      <div style="max-width:400px;margin:0 auto">
        <h1 style="font-size:24px;font-weight:700;margin:0 0 24px">Sign In</h1>
        {% if error %}
        <div class="alert-error">{{ error }}</div>
        {% endif %}
        <form method="POST" action="/account/login">
          <input type="hidden" name="authenticity_token" value="">
          <input type="email"    name="email"    placeholder="Email address" required>
          <input type="password" name="password" placeholder="Password"      required>
          <button type="submit" class="btn" style="width:100%">Sign In</button>
        </form>
        <p style="margin-top:16px;text-align:center;color:#6b7280;font-size:14px">
          No account? <a href="/account/register">Create one</a>
        </p>
      </div>
    HTML

    DEFAULT_CUSTOMER_REGISTER = <<~HTML.freeze
      <div style="max-width:400px;margin:0 auto">
        <h1 style="font-size:24px;font-weight:700;margin:0 0 24px">Create Account</h1>
        {% if error %}
        <div class="alert-error">{{ error }}</div>
        {% endif %}
        <form method="POST" action="/account/register">
          <input type="hidden" name="authenticity_token" value="">
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
            <input type="text"  name="first_name" placeholder="First name" required>
            <input type="text"  name="last_name"  placeholder="Last name"  required>
          </div>
          <input type="email"    name="email"    placeholder="Email address" required>
          <input type="password" name="password" placeholder="Password (min 8 chars)" required minlength="8">
          <button type="submit" class="btn" style="width:100%">Create Account</button>
        </form>
        <p style="margin-top:16px;text-align:center;color:#6b7280;font-size:14px">
          Already have an account? <a href="/account/login">Sign in</a>
        </p>
      </div>
    HTML

    DEFAULT_CUSTOMER_ACCOUNT = <<~HTML.freeze
      <h1 style="font-size:24px;font-weight:700;margin:0 0 8px">My Account</h1>
      <p style="color:#6b7280;margin:0 0 24px">Welcome, {{ customer.first_name }}!</p>
      <h2 style="font-size:18px;font-weight:600;margin:0 0 16px">Recent Orders</h2>
      {% if recent_orders %}
        {% for order in recent_orders %}
        <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:16px;margin-bottom:12px;display:flex;justify-content:space-between;align-items:center">
          <div>
            <strong>{{ order.order_number }}</strong>
            <span style="color:#6b7280;font-size:13px;margin-left:12px">{{ order.created_at }}</span>
          </div>
          <div style="text-align:right">
            <span style="font-weight:600">{{ order.currency }} {{ order.total_price }}</span>
            <a href="/account/orders/{{ order.id }}" style="display:block;font-size:12px;color:#6b7280;margin-top:4px">View →</a>
          </div>
        </div>
        {% endfor %}
        <a href="/account/orders" style="color:#6b7280;font-size:14px">View all orders →</a>
      {% endif %}
      <hr style="border:none;border-top:1px solid #e5e7eb;margin:32px 0">
      <a href="/account/logout" style="color:#dc2626;font-size:14px">Sign out</a>
    HTML

    DEFAULT_TEMPLATES = [
      { name: "layout",               content: DEFAULT_LAYOUT               },
      { name: "index",                content: DEFAULT_INDEX                },
      { name: "product",              content: DEFAULT_PRODUCT              },
      { name: "cart",                 content: DEFAULT_CART                 },
      { name: "checkout",             content: DEFAULT_CHECKOUT             },
      { name: "order_confirmation",   content: DEFAULT_ORDER_CONFIRMATION   },
      { name: "customer_login",       content: DEFAULT_CUSTOMER_LOGIN       },
      { name: "customer_register",    content: DEFAULT_CUSTOMER_REGISTER    },
      { name: "customer_account",     content: DEFAULT_CUSTOMER_ACCOUNT     }
    ].freeze
  end
end
