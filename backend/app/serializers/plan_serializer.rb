class PlanSerializer < ActiveModel::Serializer
  attributes :id, :name, :price_monthly, :price_yearly, :features,
             :sort_order, :active, :created_at

  def price_monthly = object.price_monthly.to_s
  def price_yearly  = object.price_yearly.to_s
end
