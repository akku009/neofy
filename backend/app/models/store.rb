class Store < ApplicationRecord
  belongs_to :user

  has_many :products,    dependent: :destroy
  has_many :variants,    dependent: :destroy
  has_many :customers,   dependent: :destroy
  has_many :orders,      dependent: :destroy
  has_many :order_items, dependent: :destroy
  has_many :payments,    dependent: :destroy
  has_many :themes,      dependent: :destroy
  has_many :domains,          dependent: :destroy
  has_many :subscriptions,    dependent: :destroy
  has_many :memberships,      class_name: "StoreMembership", dependent: :destroy
  has_many :members,          through: :memberships, source: :user
  has_many :discounts,        dependent: :destroy
  has_many :shipping_zones,   dependent: :destroy
  has_many :carts,            dependent: :destroy

  after_create :provision_default_theme!

  def active_subscription
    TenantScoped.with_bypass { subscriptions.current.order(created_at: :desc).first }
  end

  def active_plan
    active_subscription&.plan
  end

  def on_free_plan?
    active_subscription.nil? || active_subscription.plan.price_monthly.zero?
  end

  def active_theme
    TenantScoped.with_bypass { themes.find_by(active: true) }
  end

  def to_template_hash
    {
      "name"                   => name,
      "subdomain"              => subdomain,
      "currency"               => currency,
      "email"                  => email.to_s,
      "stripe_publishable_key" => ENV.fetch("STRIPE_PUBLISHABLE_KEY", "")
    }
  end

  # 0=active, 1=inactive, 2=suspended
  enum :status, { active: 0, inactive: 1, suspended: 2 }, prefix: true
  # 0=free, 1=basic, 2=pro, 3=enterprise
  enum :plan,   { free: 0, basic: 1, pro: 2, enterprise: 3 }, prefix: true

  scope :filter_by_status, ->(s) { s.present? ? where(status: s) : all }

  validates :name,      presence: true, length: { maximum: 255 }
  validates :subdomain, presence: true,
                        uniqueness: { case_sensitive: false },
                        length: { minimum: 3, maximum: 63 },
                        format: {
                          with: /\A[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?\z/,
                          message: "only allows lowercase letters, numbers, and hyphens"
                        }
  validates :currency,  presence: true
  validates :timezone,  presence: true

  before_validation :normalize_subdomain

  private

  def normalize_subdomain
    self.subdomain = subdomain&.downcase&.strip
  end

  def provision_default_theme!
    Themes::CreateDefaultTheme.call(store: self)
  end
end
