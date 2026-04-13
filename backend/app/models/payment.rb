class Payment < ApplicationRecord
  include TenantScoped

  belongs_to :order

  # 0=pending, 1=processing, 2=succeeded, 3=failed, 4=cancelled, 5=refunded
  enum :status, {
    pending: 0, processing: 1, succeeded: 2,
    failed: 3, cancelled: 4, refunded: 5
  }, prefix: true

  # 0=stripe, 1=paypal, 2=manual
  enum :provider, { stripe: 0, paypal: 1, manual: 2 }, prefix: true

  validates :amount,   presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :provider, presence: true
  validates :provider_transaction_id,
            uniqueness: true,
            allow_nil:  true

  # ── Helpers ──────────────────────────────────────────────────────────────────

  def net_amount
    amount - (refunded_amount || BigDecimal("0"))
  end

  def refund_possible?
    status_succeeded? && net_amount.positive?
  end

  # Terminal states — no further transitions possible.
  def terminal?
    status_succeeded? || status_cancelled? || status_refunded?
  end

  # Returns true if this payment can accept a new Stripe PaymentIntent.
  # Succeeded payments must not be re-charged; failed payments can retry.
  def rechargeable?
    status_pending? || status_failed?
  end

  def stripe_amount
    (amount * 100).to_i
  end
end
