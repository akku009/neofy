class AddIndexesAndConstraints < ActiveRecord::Migration[7.1]
  def change
    # ── Payments: one payment record per order ────────────────────────────────
    # The application-level idempotency guard already prevents duplicates, but
    # a DB unique constraint is the final safety net.
    add_index :payments, :order_id, unique: true,
              name: "index_payments_on_order_id_unique",
              if_not_exists: true

    # ── Subscriptions: one active subscription per store at the DB level ──────
    # status 0=trialing, 1=active — combined index for common query pattern
    add_index :subscriptions, %i[store_id status],
              name: "index_subscriptions_on_store_id_and_status",
              if_not_exists: true

    # ── Customers: composite covering index for order stats queries ───────────
    add_index :customers, %i[store_id orders_count],
              name: "index_customers_on_store_orders_count",
              if_not_exists: true

    # ── Order items: product_id for analytics top-products query ─────────────
    add_index :order_items, :product_id,
              name: "index_order_items_on_product_id",
              if_not_exists: true

    # ── Plans: sort_order for ordered listing ─────────────────────────────────
    add_index :plans, :sort_order,
              name: "index_plans_on_sort_order",
              if_not_exists: true
  end
end
