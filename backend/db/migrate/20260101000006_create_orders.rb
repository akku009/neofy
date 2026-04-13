class CreateOrders < ActiveRecord::Migration[7.1]
  def change
    create_table :orders, id: :uuid do |t|
      t.references :store,    null: false, foreign_key: true, type: :uuid
      t.references :customer, foreign_key: true, type: :uuid  # nullable (guest checkout)

      # ── Identity ──────────────────────────────────────────────────────────────
      t.string   :order_number, null: false  # e.g. "#1001"
      t.string   :email
      t.string   :phone

      # ── Statuses ──────────────────────────────────────────────────────────────
      # financial_status: 0=pending, 1=authorized, 2=partially_paid, 3=paid,
      #                   4=partially_refunded, 5=refunded, 6=voided
      t.integer  :financial_status,   null: false, default: 0
      # fulfillment_status: 0=unfulfilled, 1=partially_fulfilled, 2=fulfilled, 3=restocked
      t.integer  :fulfillment_status, null: false, default: 0

      # ── Financials ────────────────────────────────────────────────────────────
      t.string   :currency,         null: false, default: "USD"
      t.decimal  :subtotal_price,   null: false, default: 0, precision: 12, scale: 2
      t.decimal  :total_tax,        null: false, default: 0, precision: 12, scale: 2
      t.decimal  :total_discounts,  null: false, default: 0, precision: 12, scale: 2
      t.decimal  :total_price,      null: false, default: 0, precision: 12, scale: 2

      # ── Addresses (stored as JSON snapshots — immutable at time of order) ──────
      t.json     :shipping_address
      t.json     :billing_address

      # ── Metadata ──────────────────────────────────────────────────────────────
      t.text     :note
      t.string   :tags

      # ── Cancellation ──────────────────────────────────────────────────────────
      t.datetime :cancelled_at
      # 0=customer, 1=fraud, 2=inventory, 3=declined, 4=other
      t.integer  :cancel_reason

      t.datetime :processed_at

      t.timestamps
    end

    add_index :orders, :store_id
    add_index :orders, :customer_id
    add_index :orders, %i[store_id order_number],        unique: true
    add_index :orders, %i[store_id financial_status]
    add_index :orders, %i[store_id fulfillment_status]
    add_index :orders, :cancelled_at
  end
end
