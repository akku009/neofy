class CreateThemes < ActiveRecord::Migration[7.1]
  def change
    create_table :themes, id: :uuid do |t|
      t.references :store, null: false, foreign_key: true, type: :uuid

      t.string  :name,   null: false
      t.boolean :active, null: false, default: false

      t.timestamps
    end

    add_index :themes, :store_id
    add_index :themes, %i[store_id active]
  end
end
