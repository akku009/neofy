class CreateCarts < ActiveRecord::Migration[7.1]
  def change
    create_table :carts, id: :uuid do |t|
      t.references :store,    null: false, foreign_key: true, type: :uuid
      t.references :customer, foreign_key: true, type: :uuid  # nil = guest cart

      t.string   :token,       null: false  # UUID stored in browser cookie
      t.string   :currency,    null: false, default: "USD"
      t.string   :status,      null: false, default: "active"  # active | converted | abandoned
      t.datetime :completed_at
      t.timestamps
    end

    add_index :carts, :token,    unique: true
    add_index :carts, :store_id
    add_index :carts, %i[store_id status]

    create_table :cart_items, id: :uuid do |t|
      t.references :cart,    null: false, foreign_key: true, type: :uuid
      t.references :variant, null: false, foreign_key: true, type: :uuid
      t.integer    :quantity, null: false, default: 1
      t.decimal    :price,    null: false, precision: 10, scale: 2  # snapshot at add-time
      t.timestamps
    end

    add_index :cart_items, %i[cart_id variant_id], unique: true
  end
end
