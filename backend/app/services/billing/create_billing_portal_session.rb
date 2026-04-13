module Billing
  class CreateBillingPortalSession < ApplicationService
    def initialize(store:, return_url:)
      @store      = store
      @return_url = return_url
    end

    def call
      sub = @store.active_subscription
      return failure("No active subscription found") unless sub
      return failure("No Stripe customer ID on record") unless sub.stripe_customer_id.present?

      session = Stripe::BillingPortal::Session.create({
        customer:   sub.stripe_customer_id,
        return_url: @return_url
      })

      success({ url: session.url })
    rescue Stripe::StripeError => e
      failure("Stripe portal error: #{e.message}")
    end
  end
end
