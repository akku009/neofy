class Customer < ApplicationRecord
  include TenantScoped
  include SoftDeletable

  # Storefront customer login (separate from store owner User auth)
  has_secure_password validations: false  # password is optional for admin-created customers

  has_many :orders, dependent: :nullify
  has_many :carts,  dependent: :destroy

  validates :email, presence: true,
                    uniqueness: { scope: :store_id, case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def has_account?
    password_digest.present?
  end

  def generate_remember_token!
    update!(remember_token: SecureRandom.urlsafe_base64(32))
    remember_token
  end

  def clear_remember_token!
    update_column(:remember_token, nil)
  end
end
