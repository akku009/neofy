class CreateStoreMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :store_memberships, id: :uuid do |t|
      t.references :store, null: false, foreign_key: true, type: :uuid
      t.references :user,  null: false, foreign_key: true, type: :uuid

      # 0=owner (auto-created on store creation), 1=admin, 2=staff
      t.integer :role,   null: false, default: 1
      t.string  :status, null: false, default: "active"  # active | invited | suspended
      t.string  :invite_token
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :store_memberships, %i[store_id user_id], unique: true
    add_index :store_memberships, :invite_token, unique: true, where: "invite_token IS NOT NULL"
    add_index :store_memberships, %i[store_id role]
  end
end
