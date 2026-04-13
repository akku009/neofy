class CustomerSerializer < ActiveModel::Serializer
  attributes :id,
             :email,
             :first_name,
             :last_name,
             :full_name,
             :phone,
             :accepts_marketing,
             :orders_count,
             :total_spent,
             :created_at

  def full_name
    object.full_name
  end

  def total_spent
    object.total_spent&.to_s
  end
end
