class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments, id: :uuid do |t|
      t.references :store, null: false, foreign_key: true, type: :uuid
      t.references :order, null: false, foreign_key: true, type: :uuid

      # ── Financials ────────────────────────────────────────────────────────────
      t.decimal  :amount,                   null: false, precision: 12, scale: 2
      t.decimal  :refunded_amount,          null: false, default: 0, precision: 12, scale: 2
      t.string   :currency,                 null: false, default: "USD"

      # ── Status ────────────────────────────────────────────────────────────────
      # 0=pending, 1=processing, 2=succeeded, 3=failed, 4=cancelled, 5=refunded
      t.integer  :status,                   null: false, default: 0

      # ── Provider ──────────────────────────────────────────────────────────────
      # 0=stripe, 1=paypal, 2=manual
      t.integer  :provider,                 null: false, default: 0
      t.string   :provider_transaction_id   # Stripe PaymentIntent ID / charge ID
      t.json     :provider_response         # Raw provider response (audit log)
      t.text     :error_message             # Last error from provider

      t.datetime :processed_at

      t.timestamps
    end

    add_index :payments, :store_id
    add_index :payments, :order_id
    add_index :payments, %i[store_id status]
    # Provider transaction IDs are unique globally per provider
    add_index :payments, :provider_transaction_id,
              unique: true,
              where: "provider_transaction_id IS NOT NULL"
  end
end
