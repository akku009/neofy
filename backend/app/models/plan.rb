class Plan < ApplicationRecord
  has_many :subscriptions

  UNLIMITED = -1

  validates :name,          presence: true, uniqueness: { case_sensitive: false }
  validates :price_monthly, numericality: { greater_than_or_equal_to: 0 }
  validates :price_yearly,  numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true).order(:sort_order) }

  # ── Feature access ────────────────────────────────────────────────────────────
  # Reads from the features JSON column with a safe default fallback.
  def feature(key)
    (features || {}).fetch(key.to_s, nil)
  end

  def allows_unlimited?(key)
    feature(key) == UNLIMITED || feature(key).nil?
  end

  # ── Stripe price helpers ──────────────────────────────────────────────────────
  def stripe_price_id_for(interval)
    case interval.to_s
    when "yearly"  then stripe_yearly_price_id
    when "monthly" then stripe_monthly_price_id
    end
  end

  # ── Default plan definitions (used in seeds) ─────────────────────────────────
  FREE_FEATURES = {
    "max_products"    => 10,
    "max_staff"       => 1,
    "custom_domain"   => false,
    "analytics"       => false,
    "priority_support"=> false,
    "api_rate_limit"  => 100
  }.freeze

  BASIC_FEATURES = {
    "max_products"    => 100,
    "max_staff"       => 3,
    "custom_domain"   => true,
    "analytics"       => false,
    "priority_support"=> false,
    "api_rate_limit"  => 300
  }.freeze

  GROW_FEATURES = {
    "max_products"    => 1000,
    "max_staff"       => 10,
    "custom_domain"   => true,
    "analytics"       => true,
    "priority_support"=> false,
    "api_rate_limit"  => 1000
  }.freeze

  ADVANCED_FEATURES = {
    "max_products"    => UNLIMITED,
    "max_staff"       => UNLIMITED,
    "custom_domain"   => true,
    "analytics"       => true,
    "priority_support"=> true,
    "api_rate_limit"  => UNLIMITED
  }.freeze
end
