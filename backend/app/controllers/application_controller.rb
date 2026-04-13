class ApplicationController < ActionController::API
  include ActionController::MimeResponds
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :set_current_attributes
  before_action :resolve_tenant_from_subdomain

  rescue_from ActiveRecord::RecordNotFound,        with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid,         with: :render_unprocessable
  rescue_from Pundit::NotAuthorizedError,          with: :render_forbidden
  rescue_from ActionController::ParameterMissing,  with: :render_bad_request
  rescue_from TenantScoped::TenantNotSetError,     with: :render_tenant_error

  private

  # ── Current attributes ───────────────────────────────────────────────────────
  def set_current_attributes
    Current.user       = current_user
    Current.request_id = request.uuid
  end

  # ── Tenant resolution ────────────────────────────────────────────────────────
  # Delegates to Tenants::ResolveFromRequest which supports:
  #   1. X-Store-Subdomain header (explicit API/mobile override)
  #   2. Custom domain lookup    (mystore.com → Domain table → Store)
  #   3. Subdomain pattern       (my-store.neofy.com → subdomain match)
  #   4. :store_id URL param     (admin API fallback)
  def resolve_tenant_from_subdomain
    store = Tenants::ResolveFromRequest.call(request)

    if store.present?
      unless store.status_active?
        render json: { error: "This store is not active" }, status: :forbidden and return
      end

      # ── API-context ownership gate ───────────────────────────────────────────
      # When a store is resolved from subdomain or X-Store-Subdomain header in an
      # *authenticated API request*, verify the current user is a member/owner.
      # This prevents an authenticated user (owner of Store A) from setting
      # Current.store to Store B via a forged header and accessing unprotected endpoints.
      #
      # The storefront (StorefrontController) skips this check — it's public.
      if current_user.present?
        is_member = TenantScoped.with_bypass do
          store.memberships.where(user_id: current_user.id, status: "active").exists? ||
            store.user_id == current_user.id
        end
        unless is_member || current_user.role_admin?
          render json: { error: "Not found" }, status: :not_found and return
        end
      end

      Current.store = store
    elsif params[:store_id].present?
      resolve_tenant_from_param
    end
    # No resolution → platform-level request (auth routes don't need a store)
  end

  # Tenant resolution via explicit :store_id URL param.
  # Accepts both store owners AND active staff members (StoreMembership).
  def resolve_tenant_from_param
    store = TenantScoped.with_bypass do
      # Owner path — direct association
      found = current_user.stores.find_by(id: params[:store_id])
      # Staff path — via membership (e.g. staff invited via MembershipsController)
      found ||= Store.joins(:memberships)
                     .find_by(
                       id: params[:store_id],
                       store_memberships: { user_id: current_user.id, status: "active" }
                     )
      found
    end
    if store.nil? || !store.status_active?
      render json: { error: "Store not found or access denied" }, status: :not_found and return
    end
    Current.store = store
  end

  # ── Enforce store context ────────────────────────────────────────────────────
  # Add as before_action in controllers that require a resolved store.
  def require_store_context!
    return if Current.store.present?

    render json: { error: "No store context. Provide a subdomain, custom domain, or store_id." },
           status: :unprocessable_entity
  end

  # ── Response helpers ─────────────────────────────────────────────────────────
  def render_not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def render_unprocessable(exception)
    render json: { errors: exception.record.errors.full_messages },
           status: :unprocessable_entity
  end

  def render_forbidden
    render json: { error: "Access denied" }, status: :forbidden
  end

  def render_bad_request(exception)
    render json: { error: exception.message }, status: :bad_request
  end

  def render_tenant_error(exception)
    render json: { error: exception.message }, status: :internal_server_error
  end
end
