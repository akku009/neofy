require "cgi"

module Storefront
  # Base controller for all public storefront HTML controllers.
  # Inherits ActionController::Base (not API) to get cookies + session support.
  class BaseController < ActionController::Base
    include ActionController::Cookies

    protect_from_forgery with: :null_session   # CSRF: null session for JSON requests
    before_action :resolve_storefront_tenant!
    before_action :load_active_theme!
    before_action :set_current_customer

    helper_method :current_customer, :cart_item_count

    # ── Storefront pages ──────────────────────────────────────────────────────

    # GET /
    def index
      products = TenantScoped.with_bypass do
        @store.products.status_active.published
              .includes(:variants).order(created_at: :desc).limit(24)
      end
      render_storefront_template("index", {
        store:        @store.to_template_hash,
        products:     products.map(&:to_template_hash),
        page_title:   "Shop",
        canonical_url: request.base_url + "/"
      })
    end

    # GET /products/:handle
    def product
      product = TenantScoped.with_bypass do
        @store.products.status_active.find_by!(handle: params[:handle])
      end
      variants = TenantScoped.with_bypass { product.variants.order(:position) }

      render_storefront_template("product", {
        store:        @store.to_template_hash,
        product:      product.to_template_hash,
        variants:     variants.map(&:to_template_hash),
        page_title:   product.title,
        canonical_url: request.base_url + "/products/#{product.handle}"
      })
    rescue ActiveRecord::RecordNotFound
      render_storefront_error("Product not found", :not_found)
    end

    private

    def resolve_storefront_tenant!
      @store = Tenants::ResolveFromRequest.call(request)

      unless @store
        return render_storefront_error("Store not found for this domain", :not_found)
      end
      unless @store.status_active?
        return render_storefront_error("This store is currently unavailable", :forbidden)
      end
      Current.store = @store
    end

    def load_active_theme!
      @theme = @store.active_theme
      render_storefront_error("No active theme", :not_found) unless @theme
    end

    def set_current_customer
      token = cookies.signed[:customer_token]
      @current_customer = token ? TenantScoped.with_bypass { Customer.find_by(remember_token: token, store_id: @store.id) } : nil
    end

    def current_customer = @current_customer
    def logged_in?       = current_customer.present?

    def require_customer_login!
      return if logged_in?
      redirect_to "/account/login?return_to=#{CGI.escape(request.path)}", notice: "Please log in."
    end

    # Returns count without creating a cart — safe for every page render.
    def cart_item_count
      existing_cart&.items_count || 0
    rescue ActiveRecord::StatementInvalid, PG::Error, Mysql2::Error => e
      Rails.logger.warn("[Storefront] cart_item_count error: #{e.message}")
      0
    end

    # Finds existing cart from cookie. Creates one only when needed (e.g. add to cart).
    def existing_cart
      token = cookies.signed[:cart_token]
      return nil unless token.present?
      @existing_cart ||= TenantScoped.with_bypass do
        Cart.find_by(token: token, store_id: @store.id, status: "active")
      end
    end

    # Returns existing cart or creates a new one (called only from cart actions).
    def current_cart
      @current_cart ||= existing_cart || create_cart!
    end

    def create_cart!
      cart = TenantScoped.with_bypass do
        Cart.create!(store_id: @store.id, customer: current_customer, currency: @store.currency)
      end
      cookies.signed[:cart_token] = {
        value:     cart.token,
        expires:   7.days,
        httponly:  true,
        secure:    Rails.env.production?,
        same_site: :lax
      }
      cart
    end

    def render_storefront_template(name, context = {})
      page_template = TenantScoped.with_bypass { @theme.templates.find_by(name: name) }
      return render_storefront_error("Template '#{name}' not found", :not_found) unless page_template

      merged_context = global_context.merge(context)
      html = wrap_with_layout(page_template.content, merged_context)
      result = Theme::RenderTemplate.call(template: html, context: merged_context)

      if result.success?
        render html: result.object.html_safe, status: :ok, content_type: "text/html"
      else
        render_storefront_error("Template error", :internal_server_error)
      end
    end

    def wrap_with_layout(content, context)
      layout = TenantScoped.with_bypass { @theme.templates.find_by(name: "layout") }
      return content unless layout
      layout.content.gsub("{{ content_for_layout }}", content)
    end

    def global_context
      {
        store:     @store.to_template_hash,
        customer:  current_customer ? customer_context : {},
        cart_count: cart_item_count.to_s
      }
    end

    def customer_context
      {
        "id"         => current_customer.id,
        "email"      => current_customer.email,
        "first_name" => current_customer.first_name.to_s,
        "full_name"  => current_customer.full_name
      }
    end

    def render_storefront_error(message, status)
      safe_name   = CGI.escapeHTML(@store&.name || "Store")
      safe_status = CGI.escapeHTML(status.to_s.humanize)
      safe_msg    = CGI.escapeHTML(message.to_s)

      render html: <<~HTML.html_safe, status: status, content_type: "text/html"
        <!DOCTYPE html><html><head><title>Error &mdash; #{safe_name}</title>
        <style>body{font-family:sans-serif;padding:40px;color:#374151}</style>
        </head><body><h1>#{safe_status}</h1><p>#{safe_msg}</p>
        <a href="/">&#8592; Home</a></body></html>
      HTML
    end
  end
end
