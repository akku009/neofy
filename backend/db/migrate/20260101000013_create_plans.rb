class CreatePlans < ActiveRecord::Migration[7.1]
  def change
    create_table :plans, id: :uuid do |t|
      t.string  :name,            null: false
      t.decimal :price_monthly,   null: false, precision: 10, scale: 2, default: 0
      t.decimal :price_yearly,    null: false, precision: 10, scale: 2, default: 0
      t.json    :features,        null: false, default: "{}"
      t.string  :stripe_monthly_price_id   # Stripe Price ID for monthly billing
      t.string  :stripe_yearly_price_id    # Stripe Price ID for yearly billing
      t.boolean :active,          null: false, default: true
      t.integer :sort_order,      null: false, default: 0

      t.timestamps
    end

    add_index :plans, :name, unique: true
  end
end
