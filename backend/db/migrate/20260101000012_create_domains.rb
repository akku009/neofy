class CreateDomains < ActiveRecord::Migration[7.1]
  def change
    create_table :domains, id: :uuid do |t|
      t.references :store, null: false, foreign_key: true, type: :uuid

      # ── Domain ────────────────────────────────────────────────────────────────
      t.string  :domain,              null: false  # e.g. "mystore.com"

      # ── Status ────────────────────────────────────────────────────────────────
      t.boolean :verified,            null: false, default: false
      t.boolean :primary,             null: false, default: false  # primary domain for this store
      t.datetime :verified_at

      # ── Verification ──────────────────────────────────────────────────────────
      # User must add DNS TXT record: neofy-verification=<token>
      t.string  :verification_token,  null: false

      t.timestamps
    end

    add_index :domains, :domain,             unique: true   # globally unique across all stores
    add_index :domains, :verification_token, unique: true
    add_index :domains, :store_id
    add_index :domains, %i[store_id verified]
    add_index :domains, %i[store_id primary]
  end
end
