class CreateShipping < ActiveRecord::Migration[7.1]
  def change
    create_table :shipping_zones, id: :uuid do |t|
      t.references :store, null: false, foreign_key: true, type: :uuid
      t.string   :name,      null: false        # "Domestic", "International"
      t.json     :countries  # ["US","CA"] or ["*"] for rest of world
      t.boolean  :active,    null: false, default: true
      t.integer  :position,  null: false, default: 1
      t.timestamps
    end

    add_index :shipping_zones, :store_id

    create_table :shipping_rates, id: :uuid do |t|
      t.references :shipping_zone, null: false, foreign_key: true, type: :uuid
      t.string   :name,                null: false  # "Standard", "Express"
      t.decimal  :price,               null: false, precision: 10, scale: 2
      t.decimal  :min_order_amount,    precision: 12, scale: 2  # free shipping above this
      t.decimal  :min_weight,          precision: 10, scale: 3
      t.decimal  :max_weight,          precision: 10, scale: 3
      t.integer  :estimated_days_min
      t.integer  :estimated_days_max
      t.boolean  :active,              null: false, default: true
      t.timestamps
    end

    add_index :shipping_rates, :shipping_zone_id

    # Add shipping_rate snapshot to orders
    add_column :orders, :shipping_rate_id,    :string, limit: 36
    add_column :orders, :shipping_rate_name,  :string
    add_column :orders, :shipping_price,      :decimal, precision: 10, scale: 2, default: 0
  end
end
