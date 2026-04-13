class Variant < ApplicationRecord
  include TenantScoped
  include SoftDeletable

  belongs_to :product

  # 0=deny (prevent overselling), 1=continue (allow overselling)
  enum :inventory_policy, { deny: 0, continue: 1 }, prefix: true
  # 0=kg, 1=g, 2=lb, 3=oz
  enum :weight_unit, { kg: 0, g: 1, lb: 2, oz: 3 }, prefix: true

  validates :title,    presence: true
  validates :price,    presence: true,
                       numericality: { greater_than_or_equal_to: 0 }
  validates :inventory_quantity, numericality: { only_integer: true }
  validates :sku,      uniqueness: { scope: :store_id },
                       allow_blank: true
  validates :position, numericality: { only_integer: true, greater_than: 0 }

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :in_stock,   -> { where("inventory_quantity > 0") }
  scope :out_of_stock, -> { where(inventory_quantity: 0) }

  # ── Inventory helpers ────────────────────────────────────────────────────────
  LOW_STOCK_THRESHOLD = 5

  def in_stock?
    inventory_quantity.positive?
  end

  def out_of_stock?
    inventory_quantity <= 0
  end

  def low_stock?
    inventory_quantity.positive? && inventory_quantity <= LOW_STOCK_THRESHOLD
  end

  def display_name
    [product&.title, title].compact.join(" - ")
  end

  def to_template_hash
    {
      "id"                 => id,
      "title"              => title,
      "sku"                => sku.to_s,
      "price"              => price&.to_s || "0.00",
      "compare_at_price"   => compare_at_price&.to_s,
      "inventory_quantity" => inventory_quantity,
      "in_stock"           => in_stock?,
      "option1"            => option1.to_s,
      "option2"            => option2.to_s,
      "option3"            => option3.to_s,
      "image_url"          => image_url.to_s
    }
  end
end
