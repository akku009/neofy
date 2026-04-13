class OrderSerializer < ActiveModel::Serializer
  attributes :id,
             :order_number,
             :email,
             :financial_status,
             :fulfillment_status,
             :currency,
             :subtotal_price,
             :total_tax,
             :total_discounts,
             :total_price,
             :items_count,
             :shipping_address,
             :billing_address,
             :note,
             :cancel_reason,
             :cancelled_at,
             :processed_at,
             :created_at,
             :updated_at

  has_many   :order_items, serializer: OrderItemSerializer
  belongs_to :customer,   serializer: CustomerSerializer
  has_one    :payment,    serializer: PaymentSerializer

  # ── Decimal → String to preserve precision across JSON layers ────────────────
  def subtotal_price  = object.subtotal_price&.to_s
  def total_tax       = object.total_tax&.to_s
  def total_discounts = object.total_discounts&.to_s
  def total_price     = object.total_price&.to_s

  def items_count
    object.order_items.size
  end
end
