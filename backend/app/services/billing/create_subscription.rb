module Billing
  class CreateSubscription < ApplicationService
    TRIAL_DAYS = 14

    def initialize(store:, plan:, interval: "monthly")
      @store    = store
      @plan     = plan
      @interval = interval
    end

    def call
      return failure("Plan is not available") unless @plan.active?

      stripe_price_id = @plan.stripe_price_id_for(@interval)
      return failure("Stripe price not configured for this plan/interval") unless stripe_price_id.present?

      # Lock the store row to prevent two concurrent subscription creation requests
      # (e.g. double-click submit) from both passing the active_subscription check.
      locked_store = TenantScoped.with_bypass { Store.lock.find(@store.id) }
      existing = TenantScoped.with_bypass { locked_store.subscriptions.current.first }
      return failure("Store already has an active subscription") if existing.present?

      customer   = find_or_create_stripe_customer!
      stripe_sub = create_stripe_subscription!(customer.id, stripe_price_id)

      # If the DB write fails after Stripe succeeds, we log the Stripe subscription ID
      # so it can be manually reconciled. We cannot roll back a Stripe API call.
      subscription = TenantScoped.with_bypass do
        Subscription.create!(
          store_id:               @store.id,
          plan:                   @plan,
          stripe_customer_id:     customer.id,
          stripe_subscription_id: stripe_sub.id,
          billing_interval:       @interval,
          status:                 :trialing,
          current_period_start:   Time.zone.at(stripe_sub.current_period_start),
          current_period_end:     Time.zone.at(stripe_sub.current_period_end),
          trial_end:              stripe_sub.trial_end ? Time.zone.at(stripe_sub.trial_end) : nil
        )
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error(
          "[Billing::CreateSubscription] DB write failed after Stripe succeeded! " \
          "stripe_subscription_id=#{stripe_sub.id} store_id=#{@store.id} error=#{e.message}. " \
          "Manual reconciliation required."
        )
        raise
      end

      SubscriptionMailer.activated(@store, subscription).deliver_later

      success(subscription)
    rescue Stripe::StripeError => e
      Rails.logger.error("[Billing::CreateSubscription] Stripe error: #{e.message}")
      failure("Payment provider error: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    def find_or_create_stripe_customer!
      # Look for existing customer via existing subscriptions
      existing_sub = TenantScoped.with_bypass { @store.subscriptions.order(created_at: :desc).first }
      if existing_sub&.stripe_customer_id.present?
        return Stripe::Customer.retrieve(existing_sub.stripe_customer_id)
      end

      Stripe::Customer.create(
        email:    @store.email.presence || @store.user.email,
        name:     @store.name,
        metadata: { neofy_store_id: @store.id, neofy_subdomain: @store.subdomain }
      )
    end

    def create_stripe_subscription!(customer_id, price_id)
      Stripe::Subscription.create(
        {
          customer:           customer_id,
          items:              [{ price: price_id }],
          trial_period_days:  TRIAL_DAYS,
          payment_behavior:   "default_incomplete",
          payment_settings:   { save_default_payment_method: "on_subscription" },
          expand:             ["latest_invoice.payment_intent"],
          metadata:           { neofy_store_id: @store.id }
        },
        { idempotency_key: "subscription_store_#{@store.id}_#{@plan.id}_#{@interval}" }
      )
    end
  end
end
