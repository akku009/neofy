require "sidekiq/web"

Rails.application.routes.draw do
  # ── Root Route ───────────────────────────────────────────────────────────────
  root to: "application#welcome"
  
  # ── Health Check ─────────────────────────────────────────────────────────────
  get "health", to: "application#health"

  # ── Sidekiq Web UI (admin only — protected in production) ──────────────────
  authenticate :user, ->(u) { u.role_admin? } do
    mount Sidekiq::Web => "/sidekiq"
  end

  # ── Auth (platform-level — no subdomain constraint) ────────────────────────
  devise_for :users,
    controllers: {
      sessions:      "api/v1/auth/sessions",
      registrations: "api/v1/auth/registrations",
      passwords:     "api/v1/auth/passwords"
    }

  namespace :api do
    namespace :v1 do
      # ── Stripe Webhook — NO auth, NO tenant scope ─────────────────────────
      # Security: Stripe-Signature header verification only (see StripeController).
      namespace :webhooks do
        post "stripe", to: "webhooks/stripe#receive"
      end
      # ── Platform-level ────────────────────────────────────────────────────────
      resources :stores, only: %i[index show create update destroy]
      resources :plans,  only: %i[index show]  # GET /api/v1/plans

      # ── Platform admin (admin role required) ──────────────────────────────────
      namespace :admin do
        get  "analytics",           to: "analytics#platform_metrics"
        resources :stores, only: %i[index show] do
          member do
            patch :suspend  # PATCH /api/v1/admin/stores/:id/suspend
            patch :activate # PATCH /api/v1/admin/stores/:id/activate
          end
        end
      end

      # ── Tenant-scoped resources ─────────────────────────────────────────────
      # These routes accept either:
      #   a) A :store_id in the URL path (admin API / Postman)
      #   b) The subdomain on the request host (production storefront API)
      # ApplicationController#resolve_tenant_from_subdomain handles both cases.
      scope "/stores/:store_id" do
        resources :products do
          member do
            patch :publish    # PATCH /api/v1/stores/:store_id/products/:id/publish
            patch :unpublish  # PATCH /api/v1/stores/:store_id/products/:id/unpublish
          end

          resources :variants, shallow: true do
            member do
              patch :inventory  # PATCH /api/v1/variants/:id/inventory
            end
          end
        end

        resources :customers, only: %i[index show create update destroy]

        resources :orders, only: %i[index show create] do
          member do
            post :cancel          # POST /api/v1/stores/:store_id/orders/:id/cancel
            post :fulfill         # POST /api/v1/stores/:store_id/orders/:id/fulfill
            post :payment_intent  # POST /api/v1/stores/:store_id/orders/:id/payment_intent
          end
        end

        resources :payments, only: %i[index show]

        # ── Themes (admin management) ────────────────────────────────────────
        resources :themes, only: %i[index show create] do
          member do
            patch :activate   # PATCH /api/v1/stores/:store_id/themes/:id/activate
          end

          resources :templates,
                    controller: "theme_templates",
                    only:       %i[index show create update]
        end

        # ── Custom Domains ────────────────────────────────────────────────────
        resources :domains, only: %i[index show create destroy] do
          member do
            post  :verify       # POST  /api/v1/stores/:store_id/domains/:id/verify
            patch :set_primary  # PATCH /api/v1/stores/:store_id/domains/:id/set_primary
          end
        end

        # ── Subscription ─────────────────────────────────────────────────────
        resource :subscription, only: %i[show create destroy],
                                controller: "subscriptions" do
          patch :change_plan  # PATCH /api/v1/stores/:store_id/subscription/change_plan
        end

        # ── Billing Portal ────────────────────────────────────────────────────
        post "billing_portal", to: "billing_portal#create"

        # ── Store Dashboard / Analytics ───────────────────────────────────────
        get "dashboard", to: "dashboard#metrics"

        # ── Staff Memberships ─────────────────────────────────────────────────
        resources :memberships, only: %i[index create update destroy]

        # ── Discounts ─────────────────────────────────────────────────────────
        resources :discounts, only: %i[index show create update destroy] do
          collection do
            post :validate_code  # POST /api/v1/stores/:store_id/discounts/validate_code
          end
        end

        # ── Shipping ──────────────────────────────────────────────────────────
        resources :shipping_zones, only: %i[index show create update destroy] do
          member do
            post :add_rate  # POST /api/v1/stores/:store_id/shipping_zones/:id/add_rate
          end
          collection do
            get :calculate  # GET /api/v1/stores/:store_id/shipping_zones/calculate
          end
        end
      end
    end
  end

  # ── Public storefront (HTML — no auth, subdomain/custom-domain resolution) ───
  scope module: "storefront" do
    # ── Pages ────────────────────────────────────────────────────────────────
    get  "/",                    to: "base#index",            as: :storefront_home
    get  "/products/:handle",    to: "base#product",          as: :storefront_product

    # ── Cart (GET = page, POST/PATCH/DELETE = JSON API) ───────────────────────
    get    "/cart",                      to: "carts#show",      as: :storefront_cart
    post   "/cart/items",                to: "carts#add"
    patch  "/cart/items/:variant_id",    to: "carts#update"
    delete "/cart/items/:variant_id",    to: "carts#remove"

    # ── Checkout ─────────────────────────────────────────────────────────────
    get  "/checkout",         to: "checkouts#show",    as: :storefront_checkout
    post "/checkout",         to: "checkouts#create"
    get  "/checkout/success", to: "checkouts#success", as: :storefront_checkout_success

    # ── Customer accounts ─────────────────────────────────────────────────────
    get    "/account",           to: "customers#show",            as: :customer_account
    get    "/account/register",  to: "customers#new",             as: :customer_register
    post   "/account/register",  to: "customers#create"
    get    "/account/orders",    to: "customers#orders",          as: :customer_orders
    get    "/account/orders/:id",to: "customers#order",           as: :customer_order
    get    "/account/login",     to: "customer_sessions#new",     as: :customer_login
    post   "/account/login",     to: "customer_sessions#create"
    delete "/account/logout",    to: "customer_sessions#destroy", as: :customer_logout
  end

  # ── Healthcheck ─────────────────────────────────────────────────────────────
  get "up", to: proc { [200, {}, [{ status: "ok", timestamp: Time.current.iso8601 }.to_json]] }
end
