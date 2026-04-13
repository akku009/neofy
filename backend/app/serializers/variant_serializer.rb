class VariantSerializer < ActiveModel::Serializer
  attributes :id,
             :product_id,
             :title,
             :sku,
             :barcode,
             :price,
             :compare_at_price,
             :cost_per_item,
             :inventory_quantity,
             :inventory_policy,
             :weight,
             :weight_unit,
             :option1,
             :option2,
             :option3,
             :image_url,
             :position,
             :taxable,
             :requires_shipping,
             :in_stock,
             :low_stock,
             :created_at,
             :updated_at

  def price
    object.price&.to_s
  end

  def compare_at_price
    object.compare_at_price&.to_s
  end

  def cost_per_item
    object.cost_per_item&.to_s
  end

  def in_stock
    object.in_stock?
  end

  def low_stock
    object.low_stock?
  end
end
