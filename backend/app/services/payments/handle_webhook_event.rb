module Payments
  class HandleWebhookEvent < ApplicationService
    HANDLED_EVENTS = %w[
      payment_intent.succeeded
      payment_intent.payment_failed
    ].freeze

    def initialize(event:)
      @event = event
    end

    def call
      Rails.logger.info("[Stripe Webhook] Processing event: #{@event.type} (#{@event.id})")

      case @event.type
      when "payment_intent.succeeded"
        handle_payment_succeeded
      when "payment_intent.payment_failed"
        handle_payment_failed
      else
        Rails.logger.info("[Stripe Webhook] Unhandled event type: #{@event.type} — skipping")
        success  # Return 200 to Stripe even for unhandled events
      end
    rescue => e
      Rails.logger.error("[Stripe Webhook] Error processing #{@event.type}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      failure("Webhook processing error: #{e.message}")
    end

    private

    def payment_intent
      @payment_intent ||= @event.data.object
    end

    # Finds our Payment record by Stripe's PaymentIntent ID.
    # Must use with_bypass since webhooks have no Current.store context.
    def find_payment
      TenantScoped.with_bypass do
        Payment.find_by(provider_transaction_id: payment_intent.id)
      end
    end

    # ── payment_intent.succeeded ───────────────────────────────────────────────
    # Idempotent: if already succeeded, return success without re-processing.
    def handle_payment_succeeded
      payment = find_payment

      unless payment
        Rails.logger.warn("[Stripe Webhook] No payment found for intent #{payment_intent.id} — may have been created outside Neofy")
        return success
      end

      # Idempotency guard — Stripe may deliver the same event more than once.
      if payment.status_succeeded?
        Rails.logger.info("[Stripe Webhook] Payment #{payment.id} already succeeded — skipping duplicate")
        return success(payment)
      end

      ActiveRecord::Base.transaction do
        payment.update!(
          status:           :succeeded,
          processed_at:     Time.current,
          provider_response: JSON.parse(payment_intent.to_json)
        )

        TenantScoped.with_bypass do
          payment.order.update!(
            financial_status: :paid,
            processed_at:     Time.current
          )
        end
      end

      Rails.logger.info("[Stripe Webhook] Order #{payment.order.order_number} marked as PAID")
      success(payment)
    end

    # ── payment_intent.payment_failed ─────────────────────────────────────────
    def handle_payment_failed
      payment = find_payment

      unless payment
        Rails.logger.warn("[Stripe Webhook] No payment found for intent #{payment_intent.id}")
        return success
      end

      return success(payment) if payment.status_failed?  # Idempotency

      error_message = payment_intent.last_payment_error&.message ||
                      "Payment failed — reason unknown"

      payment.update!(
        status:            :failed,
        error_message:     error_message,
        provider_response: JSON.parse(payment_intent.to_json)
      )

      Rails.logger.warn(
        "[Stripe Webhook] Payment failed for order #{payment.order.order_number}: #{error_message}"
      )

      success(payment)
    end
  end
end
