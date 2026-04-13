module Payments
  class CreatePaymentIntent < ApplicationService
    class PaymentError < StandardError; end

    def initialize(order:, store:)
      @order = order
      @store = store
    end

    def call
      validate_order!
      payment = find_or_create_payment!
      intent  = fetch_or_create_stripe_intent!(payment)

      payment.update!(
        provider_transaction_id: intent.id,
        status:                  :processing,
        provider_response:       JSON.parse(intent.to_json)
      )

      success({ payment: payment, client_secret: intent.client_secret })
    rescue PaymentError => e
      failure(e.message)
    rescue Stripe::StripeError => e
      Rails.logger.error("[Payments::CreatePaymentIntent] Stripe error: #{e.message}")
      failure("Payment provider error: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    # ── Validations ────────────────────────────────────────────────────────────
    def validate_order!
      raise PaymentError, "Order not found"                    unless @order
      raise PaymentError, "Order does not belong to this store" unless @order.store_id == @store.id
      raise PaymentError, "Order is already paid"              if @order.financial_status_paid?
      raise PaymentError, "Order is voided or cancelled"       if @order.financial_status_voided? || @order.cancelled_at?
      raise PaymentError, "Order total must be greater than 0" unless @order.total_price.positive?
    end

    # ── Payment record ─────────────────────────────────────────────────────────
    # Idempotent: reuse an existing payment record for the same order if it is
    # still in a rechargeable state (pending or failed). Block re-creation if
    # the payment has already succeeded.
    def find_or_create_payment!
      existing = TenantScoped.with_bypass { Payment.find_by(order_id: @order.id) }

      if existing
        raise PaymentError, "This order has already been paid" if existing.status_succeeded?
        raise PaymentError, "This order has a refunded payment" if existing.status_refunded?
        return existing if existing.rechargeable?
      end

      TenantScoped.with_bypass do
        Payment.create!(
          store_id: @store.id,
          order_id: @order.id,
          amount:   @order.total_price,
          currency: @order.currency,
          provider: :stripe,
          status:   :pending
        )
      end
    end

    # ── Stripe API ─────────────────────────────────────────────────────────────
    # If a Stripe PaymentIntent already exists for this payment record, retrieve
    # it rather than creating a new one (handles browser refresh / network retry).
    def fetch_or_create_stripe_intent!(payment)
      if payment.provider_transaction_id.present?
        Stripe::PaymentIntent.retrieve(payment.provider_transaction_id)
      else
        Stripe::PaymentIntent.create(
          {
            amount:               payment.stripe_amount,
            currency:             payment.currency.downcase,
            automatic_payment_methods: { enabled: true },
            metadata: {
              neofy_order_id:     @order.id,
              neofy_order_number: @order.order_number,
              neofy_store_id:     @store.id
            }
          },
          # Stripe idempotency key — safe to retry on network failure.
          { idempotency_key: "payment_intent_order_#{@order.id}" }
        )
      end
    end
  end
end
