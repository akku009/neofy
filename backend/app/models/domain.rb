class Domain < ApplicationRecord
  include TenantScoped

  # A valid domain: labels separated by dots, no protocol, no path.
  # e.g. "mystore.com", "shop.mystore.co.uk" — but NOT "http://..." or "mystore.com/path"
  DOMAIN_REGEX = /\A([a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?\.)+[a-z]{2,}\z/i.freeze

  # Platform-owned domains that stores must never be allowed to claim.
  RESERVED_DOMAINS = %w[
    neofy.com
    www.neofy.com
    api.neofy.com
    admin.neofy.com
    app.neofy.com
  ].freeze

  validates :domain, presence:   true,
                     uniqueness: { case_sensitive: false, message: "is already in use by another store" },
                     format:     { with: DOMAIN_REGEX, message: "is not a valid domain format" },
                     exclusion:  { in: RESERVED_DOMAINS, message: "is a reserved platform domain" }

  validates :verification_token, presence: true, uniqueness: true

  scope :verified,   -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }
  scope :primary,    -> { where(primary: true) }

  before_validation :normalize_domain
  before_validation :assign_verification_token, on: :create

  # Ensures only one primary domain per store.
  before_save :clear_sibling_primary!, if: -> { primary? && will_save_change_to_primary? }

  def txt_record_name
    "@"  # TXT record goes on the root domain
  end

  def txt_record_value
    "neofy-verification=#{verification_token}"
  end

  def mark_verified!
    update!(verified: true, verified_at: Time.current)
  end

  private

  def normalize_domain
    self.domain = domain&.downcase&.strip&.delete_prefix("www.")
  end

  def assign_verification_token
    self.verification_token ||= SecureRandom.hex(24)
  end

  def clear_sibling_primary!
    TenantScoped.with_bypass do
      Domain.where(store_id: store_id).where.not(id: id).update_all(primary: false)
    end
  end
end
