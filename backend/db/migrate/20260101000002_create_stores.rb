class CreateStores < ActiveRecord::Migration[7.1]
  def change
    create_table :stores, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid

      # ── Identity ──────────────────────────────────────────────────────────────
      t.string  :name,      null: false
      t.string  :subdomain, null: false  # e.g. "my-store" → my-store.neofy.com

      # ── Details ───────────────────────────────────────────────────────────────
      t.text    :description
      t.string  :currency,  null: false, default: "USD"
      t.string  :timezone,  null: false, default: "UTC"
      t.string  :email
      t.string  :phone

      # ── Address ───────────────────────────────────────────────────────────────
      t.string  :address_line1
      t.string  :address_line2
      t.string  :city
      t.string  :state
      t.string  :country
      t.string  :postal_code

      # ── Branding ──────────────────────────────────────────────────────────────
      t.string  :logo_url

      # ── Lifecycle ─────────────────────────────────────────────────────────────
      # status: 0=active, 1=inactive, 2=suspended
      t.integer :status, null: false, default: 0
      # plan: 0=free, 1=basic, 2=pro, 3=enterprise
      t.integer :plan,   null: false, default: 0

      t.timestamps
    end

    add_index :stores, :subdomain, unique: true
    add_index :stores, :user_id
    add_index :stores, :status
    add_index :stores, :plan
  end
end
