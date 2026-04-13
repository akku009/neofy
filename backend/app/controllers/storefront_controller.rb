require "cgi"

# Public storefront controller — renders HTML pages for store visitors.
#
# Inherits from ActionController::API (not ApplicationController) so it:
#   - Has NO authenticate_user! requirement
#   - Has NO Pundit authorization
#   - Resolves store exclusively from subdomain
#
# Security: tenant isolation via subdomain → store lookup.
# All product/theme data is filtered by store_id through explicit queries.
class StorefrontController < ActionController::API
  include ActionController::MimeResponds

  before_action :resolve_storefront_tenant!
  before_action :load_active_theme!

  # GET /
  def index
    products = TenantScoped.with_bypass do
      @store.products
            .status_active
            .published
            .includes(:variants)
            .order(created_at: :desc)
            .limit(24)
    end

    render_storefront_template("index", {
      store:    @store.to_template_hash,
      products: products.map(&:to_template_hash)
    })
  end

  # GET /products/:handle
  def product
    product = TenantScoped.with_bypass do
      @store.products.status_active.find_by!(handle: params[:handle])
    end

    variants = TenantScoped.with_bypass do
      product.variants.order(:position)
    end

    render_storefront_template("product", {
      store:    @store.to_template_hash,
      product:  product.to_template_hash,
      variants: variants.map(&:to_template_hash)
    })
  rescue ActiveRecord::RecordNotFound
    render_storefront_error("Product not found", :not_found)
  end

  private

  # ── Tenant resolution ────────────────────────────────────────────────────────
  # Resolves the store from the request using the shared Tenants::ResolveFromRequest
  # service, which supports both subdomain (my-store.neofy.com) and custom domain
  # (mystore.com) resolution in priority order.
  def resolve_storefront_tenant!
    @store = Tenants::ResolveFromRequest.call(request)

    unless @store
      return render_storefront_error(
        "No store found for host '#{request.host}'. " \
        "If you own this store, ensure your DNS is configured correctly.",
        :not_found
      )
    end

    unless @store.status_active?
      return render_storefront_error("This store is currently unavailable.", :forbidden)
    end

    Current.store = @store
  end

  def load_active_theme!
    @theme = @store.active_theme
    render_storefront_error("No active theme configured for this store", :not_found) unless @theme
  end

  # ── Template rendering ────────────────────────────────────────────────────────
  def render_storefront_template(name, context)
    page_template = TenantScoped.with_bypass { @theme.templates.find_by(name: name) }
    return render_storefront_error("Template '#{name}' not found", :not_found) unless page_template

    # Wrap page content inside the layout template
    html = wrap_with_layout(page_template.content, context)

    result = Theme::RenderTemplate.call(template: html, context: context)

    if result.success?
      render html: result.object.html_safe, status: :ok, content_type: "text/html"
    else
      render_storefront_error("Template error: #{result.errors.join(', ')}", :internal_server_error)
    end
  end

  def wrap_with_layout(page_content, context)
    layout = TenantScoped.with_bypass { @theme.templates.find_by(name: "layout") }
    return page_content unless layout

    layout.content.gsub("{{ content_for_layout }}", page_content)
  end

  def render_storefront_error(message, status)
    render html: <<~HTML.html_safe, status: status, content_type: "text/html"
      <!DOCTYPE html><html><head><title>Error</title>
      <style>body{font-family:sans-serif;padding:40px;color:#374151}h1{color:#111827}</style>
      </head><body>
      <h1>#{status.to_s.tr('_', ' ').capitalize}</h1>
      <p>#{CGI.escapeHTML(message)}</p>
      <a href="/">← Home</a>
      </body></html>
    HTML
  end

end
