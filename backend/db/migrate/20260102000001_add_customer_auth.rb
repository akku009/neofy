class AddCustomerAuth < ActiveRecord::Migration[7.1]
  def change
    # Add password_digest for storefront customer login (has_secure_password)
    add_column :customers, :password_digest,    :string
    add_column :customers, :remember_token,      :string
    add_column :customers, :reset_password_token, :string
    add_column :customers, :reset_password_sent_at, :datetime
    add_column :customers, :last_sign_in_at,     :datetime

    add_index :customers, :remember_token,       unique: true, where: "remember_token IS NOT NULL"
    add_index :customers, :reset_password_token, unique: true, where: "reset_password_token IS NOT NULL"
  end
end
