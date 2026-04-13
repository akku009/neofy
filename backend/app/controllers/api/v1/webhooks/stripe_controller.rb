module Api
  module V1
    module Webhooks
      # This controller intentionally does NOT inherit from ApplicationController.
      # It must NOT run authenticate_user!, tenant resolution, or Pundit authorization.
      # Security is provided exclusively by Stripe webhook signature verification.
      class StripeController < ActionController::API
        # Stripe sends raw JSON — must be read as raw bytes before parsing.
        before_action :verify_stripe_signature!

        # POST /api/v1/webhooks/stripe
        def receive
          # Enqueue async processing. Return 200 immediately so Stripe doesn't
          # retry due to slow processing. Stripe retries if we return non-2xx.
          StripeWebhookJob.perform_later(@event.to_json)
          render json: { received: true }, status: :ok
        end

        private

        # ── Signature verification ───────────────────────────────────────────────
        # Constructs and verifies the Stripe event from the raw request body.
        # Halts with 400 on any verification failure — never process unverified events.
        def verify_stripe_signature!
          payload   = request.body.read
          signature = request.env["HTTP_STRIPE_SIGNATURE"]

          unless signature.present?
            render json: { error: "Missing Stripe-Signature header" }, status: :bad_request and return
          end

          @event = Stripe::Webhook.construct_event(
            payload,
            signature,
            ENV.fetch("STRIPE_WEBHOOK_SECRET")
          )
        rescue Stripe::SignatureVerificationError => e
          Rails.logger.warn("[Stripe Webhook] Invalid signature: #{e.message}")
          render json: { error: "Invalid webhook signature" }, status: :bad_request
        rescue JSON::ParserError => e
          Rails.logger.warn("[Stripe Webhook] Invalid JSON payload: #{e.message}")
          render json: { error: "Invalid JSON payload" }, status: :bad_request
        rescue KeyError
          Rails.logger.error("[Stripe Webhook] STRIPE_WEBHOOK_SECRET is not configured")
          render json: { error: "Webhook secret not configured" }, status: :internal_server_error
        end
      end
    end
  end
end
