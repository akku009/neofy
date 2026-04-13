module Billing
  class CancelSubscription < ApplicationService
    # cancel_at_period_end: true  → cancel gracefully at billing cycle end (Shopify default)
    #                       false → cancel immediately (refund logic handled separately)
    def initialize(subscription:, cancel_at_period_end: true)
      @subscription        = subscription
      @cancel_at_period_end = cancel_at_period_end
    end

    def call
      unless @subscription.active_for_store?
        return failure("Subscription is already #{@subscription.status}")
      end

      if @subscription.stripe_subscription_id.present?
        cancel_stripe_subscription!
      end

      @subscription.update!(
        status:       :cancelled,
        cancelled_at: Time.current
      )

      SubscriptionMailer.cancelled(@subscription.store, @subscription).deliver_later

      success(@subscription)
    rescue Stripe::StripeError => e
      Rails.logger.error("[Billing::CancelSubscription] Stripe error: #{e.message}")
      failure("Failed to cancel subscription: #{e.message}")
    end

    private

    def cancel_stripe_subscription!
      if @cancel_at_period_end
        Stripe::Subscription.update(
          @subscription.stripe_subscription_id,
          { cancel_at_period_end: true }
        )
      else
        Stripe::Subscription.cancel(@subscription.stripe_subscription_id)
      end
    end
  end
end
