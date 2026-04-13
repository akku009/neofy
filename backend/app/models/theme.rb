class Theme < ApplicationRecord
  include TenantScoped

  has_many :templates, class_name: "ThemeTemplate", dependent: :destroy

  VALID_NAMES = %w[layout index product collection cart].freeze

  validates :name,   presence: true, length: { maximum: 255 }
  validates :active, inclusion: { in: [true, false] }

  # When activating this theme, deactivate all others for the same store atomically.
  before_save :deactivate_sibling_themes!, if: -> { active? && will_save_change_to_active? }

  # ── Helpers ──────────────────────────────────────────────────────────────────

  def activate!
    ActiveRecord::Base.transaction do
      TenantScoped.with_bypass do
        Theme.where(store_id: store_id).where.not(id: id).update_all(active: false)
      end
      update!(active: true)
    end
  end

  def template_named(name)
    templates.find_by(name: name)
  end

  private

  def deactivate_sibling_themes!
    TenantScoped.with_bypass do
      Theme.where(store_id: store_id).where.not(id: id).update_all(active: false)
    end
  end
end
