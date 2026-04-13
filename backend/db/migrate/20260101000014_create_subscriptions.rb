class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions, id: :uuid do |t|
      t.references :store, null: false, foreign_key: true, type: :uuid
      t.references :plan,  null: false, foreign_key: true, type: :uuid

      # ── Stripe ────────────────────────────────────────────────────────────────
      t.string   :stripe_subscription_id   # Stripe subscription object ID
      t.string   :stripe_customer_id,  null: false  # Stripe customer ID for the store

      # ── Status ────────────────────────────────────────────────────────────────
      # 0=trialing, 1=active, 2=past_due, 3=cancelled, 4=paused
      t.integer  :status,               null: false, default: 0

      # ── Billing cycle ─────────────────────────────────────────────────────────
      t.string   :billing_interval,     null: false, default: "monthly"  # monthly|yearly
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :trial_end
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :subscriptions, :store_id
    add_index :subscriptions, :stripe_subscription_id, unique: true, where: "stripe_subscription_id IS NOT NULL"
    add_index :subscriptions, :stripe_customer_id
    add_index :subscriptions, %i[store_id status]
  end
end
