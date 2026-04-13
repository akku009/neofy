class Cart < ApplicationRecord
  include TenantScoped

  belongs_to :customer, optional: true
  has_many   :cart_items, dependent: :destroy
  has_many   :variants, through: :cart_items

  before_create :assign_token

  enum :status, { active: "active", converted: "converted", abandoned: "abandoned" }

  scope :active_carts, -> { where(status: "active") }

  def total_price
    # Use SQL SUM to avoid loading all items into memory.
    BigDecimal(cart_items.sum("price * quantity").to_s)
  end

  def items_count
    cart_items.sum(:quantity)
  end

  MAX_QUANTITY_PER_ITEM = 100  # Storefront cart cap (API checkout cap is 1000)

  def add_item!(variant, quantity: 1)
    quantity = [[quantity.to_i, 1].max, MAX_QUANTITY_PER_ITEM].min

    ActiveRecord::Base.transaction do
      item = cart_items.find_or_initialize_by(variant_id: variant.id)
      item.price    = variant.price   # Snapshot current price
      new_qty       = (item.persisted? ? item.quantity : 0) + quantity
      item.quantity = [new_qty, MAX_QUANTITY_PER_ITEM].min
      item.save!
    end
  end

  def update_item!(variant_id, quantity)
    item = cart_items.find_by!(variant_id: variant_id)
    if quantity <= 0
      item.destroy!
    else
      item.update!(quantity: quantity)
    end
  end

  def remove_item!(variant_id)
    cart_items.find_by(variant_id: variant_id)&.destroy!
  end

  def to_checkout_params
    {
      items: cart_items.includes(:variant).map do |item|
        { variant_id: item.variant_id, quantity: item.quantity }
      end,
      currency: currency
    }
  end

  private

  def assign_token
    self.token = SecureRandom.uuid
  end
end
