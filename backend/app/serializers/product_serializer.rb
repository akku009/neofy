class ProductSerializer < ActiveModel::Serializer
  attributes :id,
             :store_id,
             :title,
             :description,
             :handle,
             :product_type,
             :vendor,
             :tags,
             :status,
             :published_at,
             :variants_count,
             :total_inventory,
             :created_at,
             :updated_at

  has_many :variants, serializer: VariantSerializer

  def tags
    object.tags_array
  end

  def variants_count
    object.variants.size
  end

  def total_inventory
    object.variants.sum(:inventory_quantity)
  end
end
