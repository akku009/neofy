class CreateThemeTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :theme_templates, id: :uuid do |t|
      t.references :theme, null: false, foreign_key: true, type: :uuid

      # name: "layout" | "index" | "product" | "collection" | "cart"
      t.string :name,    null: false
      t.text   :content, null: false

      t.timestamps
    end

    add_index :theme_templates, :theme_id
    # Each template name must be unique within a theme
    add_index :theme_templates, %i[theme_id name], unique: true
  end
end
