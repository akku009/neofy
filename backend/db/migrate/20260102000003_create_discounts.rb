class CreateDiscounts < ActiveRecord::Migration[7.1]
  def change
    create_table :discounts, id: :uuid do |t|
      t.references :store, null: false, foreign_key: true, type: :uuid

      t.string   :code,              null: false   # "SUMMER20"
      # type: 0=percentage, 1=fixed_amount
      t.integer  :discount_type,     null: false, default: 0
      t.decimal  :value,             null: false, precision: 10, scale: 2
      t.decimal  :min_order_amount,  precision: 12, scale: 2
      t.integer  :usage_limit                        # nil = unlimited
      t.integer  :usage_count,       null: false, default: 0
      t.datetime :starts_at
      t.datetime :ends_at
      t.boolean  :active,            null: false, default: true

      t.timestamps
    end

    add_index :discounts, :store_id
    add_index :discounts, %i[store_id code], unique: true
    add_index :discounts, %i[store_id active]

    # Track which orders used which discount
    add_column :orders, :discount_id,   :string, limit: 36   # UUID FK (string for compatibility)
    add_column :orders, :discount_code, :string               # snapshot of code used
  end
end
