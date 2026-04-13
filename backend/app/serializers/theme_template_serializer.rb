class ThemeTemplateSerializer < ActiveModel::Serializer
  attributes :id, :theme_id, :name, :content, :created_at, :updated_at
end
