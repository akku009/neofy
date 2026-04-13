class ShippingRate < ApplicationRecord
  belongs_to :shipping_zone

  validates :name,  presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  def free?
    price.zero?
  end

  def delivery_estimate
    return nil unless estimated_days_min || estimated_days_max
    if estimated_days_min == estimated_days_max
      "#{estimated_days_min} business days"
    else
      "#{estimated_days_min}-#{estimated_days_max} business days"
    end
  end
end
