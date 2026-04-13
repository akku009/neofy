class Subscription < ApplicationRecord
  include TenantScoped

  belongs_to :plan

  # 0=trialing, 1=active, 2=past_due, 3=cancelled, 4=paused
  enum :status, {
    trialing: 0, active: 1, past_due: 2, cancelled: 3, paused: 4
  }, prefix: true

  validates :stripe_customer_id,    presence: true
  validates :billing_interval,      inclusion: { in: %w[monthly yearly] }
  validates :stripe_subscription_id,
            uniqueness: true,
            allow_nil:  true

  scope :current, -> { where(status: %i[trialing active]) }

  # ── Helpers ──────────────────────────────────────────────────────────────────

  def active_for_store?
    status_trialing? || status_active?
  end

  def trial_active?
    status_trialing? && trial_end.present? && trial_end > Time.current
  end

  def days_remaining
    return nil unless current_period_end
    [(current_period_end.to_date - Date.current).to_i, 0].max
  end

  def sync_from_stripe!(stripe_sub)
    update!(
      status:                stripe_sub.status.gsub("-", "_").to_sym,
      current_period_start:  Time.zone.at(stripe_sub.current_period_start),
      current_period_end:    Time.zone.at(stripe_sub.current_period_end),
      trial_end:             stripe_sub.trial_end.present? ? Time.zone.at(stripe_sub.trial_end) : nil
    )
  end
end
