class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      # ── Devise: Database Authenticatable ─────────────────────────────────────
      t.string  :email,              null: false, default: ""
      t.string  :encrypted_password, null: false, default: ""

      # ── Devise: Recoverable ───────────────────────────────────────────────────
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      # ── Devise: Rememberable ──────────────────────────────────────────────────
      t.datetime :remember_created_at

      # ── Devise: Confirmable ───────────────────────────────────────────────────
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email

      # ── Devise: Trackable ─────────────────────────────────────────────────────
      t.integer  :sign_in_count,      default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      # ── devise-jwt: JTI for token revocation ──────────────────────────────────
      t.string   :jti, null: false

      # ── Profile ───────────────────────────────────────────────────────────────
      t.string   :first_name, null: false, default: ""
      t.string   :last_name,  null: false, default: ""

      # ── Platform role ─────────────────────────────────────────────────────────
      # 0 = owner (store owner), 1 = admin (platform admin)
      t.integer  :role, null: false, default: 0

      t.timestamps
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token,   unique: true
    add_index :users, :jti,                  unique: true
  end
end
