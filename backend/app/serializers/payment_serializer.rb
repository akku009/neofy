class PaymentSerializer < ActiveModel::Serializer
  attributes :id,
             :order_id,
             :provider,
             :status,
             :amount,
             :currency,
             :refunded_amount,
             :provider_transaction_id,
             :error_message,
             :net_amount,
             :refund_possible,
             :processed_at,
             :created_at,
             :updated_at

  # Serialise decimals as strings to preserve precision in JSON.
  def amount          = object.amount&.to_s
  def refunded_amount = object.refunded_amount&.to_s
  def net_amount      = object.net_amount.to_s
  def refund_possible = object.refund_possible?

  # Never expose provider_response (raw Stripe object) — it's for internal audit only.
  # Never expose client_secret — only returned at payment intent creation time.
end
