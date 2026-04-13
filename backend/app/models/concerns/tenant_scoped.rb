module TenantScoped
  extend ActiveSupport::Concern

  # Raised when a tenant-scoped model is queried without a Current.store context.
  # This is a programming error — never silently fall through to unscoped queries.
  class TenantNotSetError < StandardError
    def initialize(model = nil)
      super("Current.store is not set. Cannot query #{model} without a tenant context. " \
            "Use #{model}.for_platform to explicitly bypass tenant scoping.")
    end
  end

  included do
    belongs_to :store

    # Enforce tenant isolation at the model layer.
    # Raises TenantNotSetError if no store context is set, preventing accidental
    # cross-tenant data access even if a controller is missing before_action hooks.
    default_scope do
      if Current.store.present?
        where(store_id: Current.store.id)
      elsif TenantScoped.bypass_active?
        all
      else
        raise TenantScoped::TenantNotSetError.new(name)
      end
    end
  end

  class_methods do
    # Explicitly bypass tenant scoping for platform-level / admin operations.
    # MUST be used intentionally — never call this from tenant-facing code.
    #
    # Usage:
    #   Product.for_platform.where(status: :active)
    def for_platform
      TenantScoped.with_bypass { unscoped }
    end
  end

  # Thread-local bypass flag — allows unscoped platform queries in a controlled block.
  def self.bypass_active?
    Thread.current[:tenant_scope_bypass] == true
  end

  def self.with_bypass
    Thread.current[:tenant_scope_bypass] = true
    yield
  ensure
    Thread.current[:tenant_scope_bypass] = false
  end
end
