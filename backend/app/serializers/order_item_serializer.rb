class OrderItemSerializer < ActiveModel::Serializer
  attributes :id,
             :variant_id,
             :product_id,
             :title,
             :variant_title,
             :sku,
             :image_url,
             :quantity,
             :price,
             :total_discount,
             :line_total,
             :taxable,
             :requires_shipping,
             :fulfillment_status

  def price
    object.price&.to_s
  end

  def total_discount
    object.total_discount&.to_s
  end

  def line_total
    object.line_total.to_s
  end
end
