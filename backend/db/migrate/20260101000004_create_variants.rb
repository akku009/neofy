class CreateVariants < ActiveRecord::Migration[7.1]
  def change
    create_table :variants, id: :uuid do |t|
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.references :store,   null: false, foreign_key: true, type: :uuid

      # ── Identity ──────────────────────────────────────────────────────────────
      t.string   :title,              null: false
      t.string   :sku
      t.string   :barcode
      t.string   :image_url

      # ── Pricing ───────────────────────────────────────────────────────────────
      t.decimal  :price,              null: false, precision: 10, scale: 2
      t.decimal  :compare_at_price,   precision: 10, scale: 2
      t.decimal  :cost_per_item,      precision: 10, scale: 2

      # ── Inventory ─────────────────────────────────────────────────────────────
      t.integer  :inventory_quantity, null: false, default: 0
      # 0=deny (block oversell), 1=continue (allow oversell)
      t.integer  :inventory_policy,   null: false, default: 0

      # ── Shipping ──────────────────────────────────────────────────────────────
      t.decimal  :weight,             precision: 10, scale: 3
      # 0=kg, 1=g, 2=lb, 3=oz
      t.integer  :weight_unit,        null: false, default: 0
      t.boolean  :requires_shipping,  null: false, default: true

      # ── Options (e.g. "Red / Large / Cotton") ─────────────────────────────────
      t.string   :option1
      t.string   :option2
      t.string   :option3

      # ── Misc ──────────────────────────────────────────────────────────────────
      t.integer  :position,   null: false, default: 1
      t.boolean  :taxable,    null: false, default: true

      t.timestamps
    end

    add_index :variants, :product_id
    add_index :variants, :store_id
    # SKU must be unique per store but can be blank
    add_index :variants, %i[store_id sku], unique: true, where: "sku IS NOT NULL AND sku != ''"
  end
end
