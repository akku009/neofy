class Discount < ApplicationRecord
  include TenantScoped
  include SoftDeletable

  # 0=percentage (e.g. 20%), 1=fixed_amount (e.g. $10 off)
  enum :discount_type, { percentage: 0, fixed_amount: 1 }, prefix: true

  validates :code,           presence: true
  validates :value,          numericality: { greater_than: 0 }
  validates :discount_type,  presence: true
  validates :value, numericality: { less_than_or_equal_to: 100 }, if: :discount_type_percentage?

  before_validation :normalize_code

  scope :active_now, -> {
    where(active: true)
      .where("starts_at IS NULL OR starts_at <= ?", Time.current)
      .where("ends_at IS NULL OR ends_at >= ?", Time.current)
  }

  def applicable?(order_total)
    return false unless active?
    return false if usage_limit.present? && usage_count >= usage_limit
    return false if min_order_amount.present? && order_total < min_order_amount
    return false if starts_at.present? && starts_at > Time.current
    return false if ends_at.present? && ends_at < Time.current
    true
  end

  def calculate_discount(order_total)
    if discount_type_percentage?
      (order_total * value / 100).round(2)
    else
      [value, order_total].min
    end
  end

  def increment_usage!
    increment!(:usage_count)
  end

  private

  def normalize_code
    self.code = code&.upcase&.strip
  end
end
