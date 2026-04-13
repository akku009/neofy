class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products, id: :uuid do |t|
      t.references :store, null: false, foreign_key: true, type: :uuid

      # ── Core ──────────────────────────────────────────────────────────────────
      t.string   :title,        null: false
      t.text     :description
      t.string   :handle,       null: false  # URL-friendly slug; unique per store

      # ── Classification ────────────────────────────────────────────────────────
      t.string   :product_type
      t.string   :vendor
      t.text     :tags          # stored as comma-separated string

      # ── Lifecycle ─────────────────────────────────────────────────────────────
      # 0=draft, 1=active, 2=archived
      t.integer  :status,       null: false, default: 0
      t.datetime :published_at

      t.timestamps
    end

    add_index :products, :store_id
    add_index :products, %i[store_id handle], unique: true
    add_index :products, %i[store_id status]
  end
end
