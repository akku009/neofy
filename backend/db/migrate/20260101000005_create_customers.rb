class CreateCustomers < ActiveRecord::Migration[7.1]
  def change
    create_table :customers, id: :uuid do |t|
      t.references :store, null: false, foreign_key: true, type: :uuid

      # ── Identity ──────────────────────────────────────────────────────────────
      t.string   :email,             null: false
      t.string   :first_name
      t.string   :last_name
      t.string   :phone

      # ── Notes ─────────────────────────────────────────────────────────────────
      t.text     :notes

      # ── Marketing ─────────────────────────────────────────────────────────────
      t.boolean  :accepts_marketing, null: false, default: false

      # ── Aggregated stats (denormalized for perf) ───────────────────────────────
      t.integer  :orders_count,      null: false, default: 0
      t.decimal  :total_spent,       null: false, default: 0.0, precision: 12, scale: 2

      t.timestamps
    end

    add_index :customers, :store_id
    add_index :customers, %i[store_id email], unique: true
  end
end
