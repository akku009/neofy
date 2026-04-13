class ShippingZone < ApplicationRecord
  include TenantScoped

  has_many :shipping_rates, dependent: :destroy

  validates :name, presence: true

  scope :active, -> { where(active: true).order(:position) }

  def covers_country?(country_code)
    return true if countries.blank?
    countries.include?("*") || countries.include?(country_code.to_s.upcase)
  end

  def cheapest_rate_for(order_total: 0, weight: 0)
    shipping_rates
      .where(active: true)
      .select { |r|
        weight_ok = (r.min_weight.nil? || weight >= r.min_weight) &&
                    (r.max_weight.nil? || weight <= r.max_weight)
        min_ok    = r.min_order_amount.nil? || order_total >= r.min_order_amount
        weight_ok && min_ok
      }
      .min_by(&:price)
  end
end
