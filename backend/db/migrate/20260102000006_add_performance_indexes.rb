class AddPerformanceIndexes < ActiveRecord::Migration[7.1]
  def change
    # ── StoreMembership: covering index for ownership gate ────────────────────
    # Fired on EVERY API request via resolve_tenant_from_subdomain.
    # Without this, a full table scan occurs per request — catastrophic at scale.
    add_index :store_memberships, %i[store_id user_id status],
              name: "idx_memberships_store_user_status",
              if_not_exists: true

    # ── Cart: token lookup (storefront page render) ───────────────────────────
    add_index :carts, %i[token store_id status],
              name: "idx_carts_token_store_status",
              if_not_exists: true

    # ── Discount: code lookup with lock (checkout) ────────────────────────────
    add_index :discounts, %i[store_id code active],
              name: "idx_discounts_store_code_active",
              if_not_exists: true

    # ── Customer: remember_token lookup (storefront session) ─────────────────
    add_index :customers, %i[store_id remember_token],
              name: "idx_customers_store_remember_token",
              if_not_exists: true
  end
end
