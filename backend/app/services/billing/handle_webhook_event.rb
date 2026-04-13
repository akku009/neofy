module Billing
  # Handles Stripe subscription and invoice webhook events.
  #
  # Handled events:
  #   customer.subscription.created   → create/sync subscription record
  #   customer.subscription.updated   → sync status, period, plan changes
  #   customer.subscription.deleted   → mark subscription as cancelled
  #   invoice.paid                    → mark subscription active, sync period
  #   invoice.payment_failed          → mark subscription past_due, notify
  class HandleWebhookEvent < ApplicationService
    def initialize(event:)
      @event = event
    end

    def call
      case @event.type
      when "customer.subscription.created"  then handle_subscription_created
      when "customer.subscription.updated"  then handle_subscription_updated
      when "customer.subscription.deleted"  then handle_subscription_deleted
      when "invoice.paid"                   then handle_invoice_paid
      when "invoice.payment_failed"         then handle_invoice_payment_failed
      else
        Rails.logger.info("[Billing::HandleWebhookEvent] Unhandled: #{@event.type}")
        success
      end
    rescue => e
      Rails.logger.error("[Billing::HandleWebhookEvent] #{@event.type}: #{e.message}")
      failure(e.message)
    end

    private

    def stripe_sub
      @stripe_sub ||= @event.data.object
    end

    def find_subscription
      TenantScoped.with_bypass do
        Subscription.find_by(stripe_subscription_id: stripe_sub.id)
      end
    end

    def handle_subscription_created
      sub = find_subscription
      return success if sub.present?  # Already created via CreateSubscription service

      # Subscription created outside normal flow (e.g. Stripe dashboard)
      store = resolve_store_from_metadata
      return success unless store

      plan = resolve_plan_from_stripe_sub
      return success unless plan

      TenantScoped.with_bypass do
        Subscription.find_or_create_by!(stripe_subscription_id: stripe_sub.id) do |s|
          s.store_id              = store.id
          s.plan                  = plan
          s.stripe_customer_id    = stripe_sub.customer
          s.billing_interval      = "monthly"
          s.status                = map_stripe_status(stripe_sub.status)
          s.current_period_start  = Time.zone.at(stripe_sub.current_period_start)
          s.current_period_end    = Time.zone.at(stripe_sub.current_period_end)
          s.trial_end             = stripe_sub.trial_end ? Time.zone.at(stripe_sub.trial_end) : nil
        end
      end

      success
    end

    def handle_subscription_updated
      sub = find_subscription
      return success unless sub

      # Detect plan change via Stripe item price
      new_plan = resolve_plan_from_stripe_sub
      ActiveRecord::Base.transaction do
        sub.update!(
          plan:                  new_plan || sub.plan,
          status:                map_stripe_status(stripe_sub.status),
          current_period_start:  Time.zone.at(stripe_sub.current_period_start),
          current_period_end:    Time.zone.at(stripe_sub.current_period_end),
          trial_end:             stripe_sub.trial_end ? Time.zone.at(stripe_sub.trial_end) : nil
        )

        # Sync the denormalized plan on the store
        if new_plan && new_plan.id != sub.plan_id_previously_was
          sync_store_plan!(sub.store, new_plan)
        end
      end

      success(sub)
    end

    def handle_subscription_deleted
      sub = find_subscription
      return success unless sub

      sub.update!(status: :cancelled, cancelled_at: Time.current)
      SubscriptionMailer.cancelled(sub.store, sub).deliver_later
      success(sub)
    end

    def handle_invoice_paid
      invoice = @event.data.object
      return success unless invoice.subscription.present?

      sub = TenantScoped.with_bypass do
        Subscription.find_by(stripe_subscription_id: invoice.subscription)
      end
      return success unless sub

      sub.update!(
        status:               :active,
        current_period_start: Time.zone.at(invoice.period_start),
        current_period_end:   Time.zone.at(invoice.period_end)
      )

      success(sub)
    end

    def handle_invoice_payment_failed
      invoice = @event.data.object
      return success unless invoice.subscription.present?

      sub = TenantScoped.with_bypass do
        Subscription.find_by(stripe_subscription_id: invoice.subscription)
      end
      return success unless sub

      sub.update!(status: :past_due)
      SubscriptionMailer.payment_failed(sub.store, sub).deliver_later
      success(sub)
    end

    # ── Helpers ──────────────────────────────────────────────────────────────────

    def resolve_store_from_metadata
      store_id = stripe_sub.metadata["neofy_store_id"]
      TenantScoped.with_bypass { Store.find_by(id: store_id) }
    end

    def resolve_plan_from_stripe_sub
      price_id = stripe_sub.items&.data&.first&.price&.id
      return nil unless price_id

      TenantScoped.with_bypass do
        Plan.find_by(stripe_monthly_price_id: price_id) ||
          Plan.find_by(stripe_yearly_price_id: price_id)
      end
    end

    def sync_store_plan!(store, plan)
      plan_enum = plan.name.downcase.to_sym
      store.update!(plan: plan_enum) if Store.plans.key?(plan_enum.to_s)
    end

    def map_stripe_status(stripe_status)
      case stripe_status
      when "trialing"           then :trialing
      when "active"             then :active
      when "past_due"           then :past_due
      when "canceled", "cancelled" then :cancelled
      when "paused"             then :paused
      else :active
      end
    end
  end
end
