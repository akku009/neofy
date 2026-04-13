class StripeWebhookJob < ApplicationJob
  queue_as :critical  # Highest priority queue — webhook SLA matters

  # Signature is verified in the controller before enqueuing.
  # This job is responsible only for event processing + retries.
  #
  # Usage:
  #   StripeWebhookJob.perform_later(event_json)
  def perform(event_json)
    event  = Stripe::Event.construct_from(JSON.parse(event_json))
    result = route_event(event)

    raise "Webhook processing failed: #{result.errors.join(', ')}" if result.failure?
  rescue JSON::ParserError => e
    # Malformed JSON — discard immediately (no retry).
    Rails.logger.error("[StripeWebhookJob] Malformed event JSON: #{e.message}")
    raise DiscardJobError, "Malformed Stripe event JSON"
  end

  private

  # Route Stripe events to the appropriate handler service.
  def route_event(event)
    case event.type
    when /\Apayment_intent\./
      Payments::HandleWebhookEvent.call(event: event)
    when /\A(invoice\.|customer\.subscription\.)/
      Billing::HandleWebhookEvent.call(event: event)
    else
      Rails.logger.info("[StripeWebhookJob] Unhandled event type: #{event.type}")
      Struct.new(:success?, :failure?, :errors).new(true, false, [])
    end
  end

  # Custom error to signal this job should be discarded without retry.
  class DiscardJobError < StandardError; end
  discard_on DiscardJobError
end
