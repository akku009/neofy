module Billing
  class ChangePlan < ApplicationService
    def initialize(subscription:, new_plan:, interval: nil)
      @subscription = subscription
      @new_plan     = new_plan
      @interval     = interval || @subscription.billing_interval
    end

    def call
      return failure("New plan not found or inactive") unless @new_plan&.active?
      return failure("Already on this plan") if @subscription.plan_id == @new_plan.id

      new_price_id = @new_plan.stripe_price_id_for(@interval)
      return failure("Stripe price not configured for #{@new_plan.name}/#{@interval}") \
        unless new_price_id.present?

      unless @subscription.stripe_subscription_id.present?
        return failure("No Stripe subscription to update")
      end

      # Stripe proration: immediate invoice for upgrade, credit for downgrade
      stripe_sub = Stripe::Subscription.retrieve(@subscription.stripe_subscription_id)
      first_item  = stripe_sub.items.data.first

      Stripe::Subscription.update(
        @subscription.stripe_subscription_id,
        {
          items: [{ id: first_item.id, price: new_price_id }],
          proration_behavior: "create_prorations",   # immediate invoice
          billing_cycle_anchor: "unchanged"
        }
      )

      @subscription.update!(
        plan:             @new_plan,
        billing_interval: @interval
      )

      success(@subscription.reload)
    rescue Stripe::StripeError => e
      Rails.logger.error("[Billing::ChangePlan] Stripe error: #{e.message}")
      failure("Payment provider error: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end
  end
end
