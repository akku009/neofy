class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  # 0=owner (default), 1=admin (platform admin)
  enum :role, { owner: 0, admin: 1 }, prefix: true

  has_many :stores, dependent: :destroy

  # Expose store IDs for policy scopes without loading all store records.
  delegate :pluck, to: :stores, prefix: true, allow_nil: true
  def store_ids = stores.pluck(:id)

  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name,  presence: true, length: { maximum: 100 }

  def full_name
    "#{first_name} #{last_name}".strip
  end
end
