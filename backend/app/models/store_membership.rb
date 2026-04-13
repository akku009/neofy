class StoreMembership < ApplicationRecord
  belongs_to :store
  belongs_to :user

  # 0=owner (store creator), 1=admin, 2=staff
  enum :role, { owner: 0, admin: 1, staff: 2 }, prefix: true

  validates :role,   presence: true
  validates :status, inclusion: { in: %w[active invited suspended] }
  validates :user_id, uniqueness: { scope: :store_id, message: "is already a member of this store" }

  scope :active,  -> { where(status: "active") }
  scope :owners,  -> { where(role: :owner) }
  scope :staff,   -> { where(role: %i[admin staff]) }

  before_validation :assign_invite_token, if: -> { status == "invited" && invite_token.blank? }

  def accept_invite!
    update!(status: "active", accepted_at: Time.current, invite_token: nil)
  end

  private

  def assign_invite_token
    self.invite_token = SecureRandom.urlsafe_base64(32)
  end
end
