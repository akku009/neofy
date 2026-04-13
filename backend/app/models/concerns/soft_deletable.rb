module SoftDeletable
  extend ActiveSupport::Concern

  included do
    # Exclude soft-deleted records from all queries by default.
    default_scope { where(deleted_at: nil) }

    # IMPORTANT: Use unscope(where: :deleted_at) — NOT unscoped.
    # `unscoped` removes ALL default_scopes including TenantScoped's store_id filter,
    # which would leak data across tenants.
    # `unscope(where: :deleted_at)` removes ONLY the deleted_at condition,
    # preserving all other scopes (store_id, association constraints, etc.)
    scope :with_deleted,  -> { unscope(where: :deleted_at) }
    scope :only_deleted,  -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }
  end

  # Soft-delete: sets deleted_at timestamp instead of issuing DELETE.
  def soft_delete!
    touch(:deleted_at)
  end

  # Restore a soft-deleted record.
  def restore!
    update_column(:deleted_at, nil)
  end

  def deleted?
    deleted_at.present?
  end
end
