class ThemeTemplate < ApplicationRecord
  belongs_to :theme

  VALID_NAMES = %w[
    layout index product collection cart checkout
    order_confirmation
    customer_login customer_register customer_account
    customer_orders customer_order_detail
  ].freeze

  validates :name,    presence: true,
                      inclusion: { in: VALID_NAMES, message: "%{value} is not a valid template name" }
  validates :content, presence: true
  validates :name,    uniqueness: { scope: :theme_id, message: "already exists for this theme" }

  # Convenience accessor for the parent store (through theme)
  def store
    theme.store
  end
end
