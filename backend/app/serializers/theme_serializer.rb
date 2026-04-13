class ThemeSerializer < ActiveModel::Serializer
  attributes :id, :store_id, :name, :active, :templates_count, :created_at, :updated_at

  has_many :templates, serializer: ThemeTemplateSerializer

  def templates_count
    object.templates.size
  end
end
