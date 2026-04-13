class CreateOrderItems < ActiveRecord::Migration[7.1]
  def change
    create_table :order_items, id: :uuid do |t|
      t.references :order,   null: false, foreign_key: true, type: :uuid
      t.references :store,   null: false, foreign_key: true, type: :uuid
      t.references :variant, foreign_key: true, type: :uuid  # nullable (variant may be deleted)
      t.references :product, foreign_key: true, type: :uuid  # nullable (product may be deleted)

      # ── Snapshot fields (preserved even if product/variant is deleted) ─────────
      t.string   :title,              null: false  # product title at time of purchase
      t.string   :variant_title                    # e.g. "Red / Large"
      t.string   :sku
      t.string   :image_url

      # ── Quantity & Pricing ────────────────────────────────────────────────────
      t.integer  :quantity,           null: false
      t.decimal  :price,              null: false, precision: 10, scale: 2  # unit price
      t.decimal  :total_discount,     null: false, default: 0, precision: 10, scale: 2

      # ── Flags ─────────────────────────────────────────────────────────────────
      t.boolean  :taxable,            null: false, default: true
      t.boolean  :requires_shipping,  null: false, default: true

      # ── Fulfillment ───────────────────────────────────────────────────────────
      # 0=unfulfilled, 1=fulfilled, 2=restocked
      t.integer  :fulfillment_status, null: false, default: 0

      t.timestamps
    end

    add_index :order_items, :order_id
    add_index :order_items, :store_id
    add_index :order_items, :variant_id
  end
end
