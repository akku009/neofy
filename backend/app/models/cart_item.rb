class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :variant

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :price,    numericality: { greater_than_or_equal_to: 0 }

  def line_total
    price * quantity
  end
end
