class SubscriptionSerializer < ActiveModel::Serializer
  attributes :id, :store_id, :status, :billing_interval,
             :current_period_start, :current_period_end,
             :trial_end, :trial_active, :days_remaining,
             :cancelled_at, :created_at

  belongs_to :plan, serializer: PlanSerializer

  def trial_active   = object.trial_active?
  def days_remaining = object.days_remaining
end
