class OrderItem < ApplicationRecord
  include TenantScoped

  belongs_to :order
  belongs_to :variant, optional: true  # snapshot survives variant deletion
  belongs_to :product, optional: true  # snapshot survives product deletion

  # 0=unfulfilled, 1=fulfilled, 2=restocked
  enum :fulfillment_status, {
    unfulfilled: 0, fulfilled: 1, restocked: 2
  }, prefix: true

  validates :title,    presence: true
  validates :quantity, presence: true,
                       numericality: { only_integer: true, greater_than: 0 }
  validates :price,    presence: true,
                       numericality: { greater_than_or_equal_to: 0 }

  # Total for this line after discounts. Safe against nil total_discount.
  def line_total
    (price * quantity) - (total_discount || BigDecimal("0"))
  end

  def gross_total
    price * quantity
  end
end
