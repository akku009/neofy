module Fraud
  # Basic fraud detection using rule-based scoring.
  # Returns a risk score (0-100) and a recommendation (allow/review/block).
  #
  # This intentionally keeps rules simple for an MVP.
  # Future: integrate Stripe Radar or a dedicated fraud API.
  class CheckOrder < ApplicationService
    RISK_THRESHOLDS = { review: 40, block: 70 }.freeze

    def initialize(order:)
      @order = order
      @score = 0
      @flags = []
    end

    def call
      run_checks!
      recommendation = risk_recommendation

      Rails.logger.info(
        "[Fraud::CheckOrder] Order #{@order.order_number} risk_score=#{@score} " \
        "recommendation=#{recommendation} flags=#{@flags.inspect}"
      )

      success({
        order_id:       @order.id,
        risk_score:     @score,
        recommendation: recommendation,
        flags:          @flags
      })
    end

    private

    def run_checks!
      check_order_velocity!
      check_high_value_guest!
      check_multiple_failed_payments!
      check_suspicious_email!
    end

    # Flag if the same IP created > 3 orders in the last hour
    def check_order_velocity!
      return unless @order.email.present?

      recent = TenantScoped.with_bypass do
        @order.store.orders
              .where(email: @order.email)
              .where("created_at > ?", 1.hour.ago)
              .where.not(id: @order.id)
              .count
      end

      if recent >= 5
        @score += 60
        @flags << "high_order_velocity_by_email"
      elsif recent >= 3
        @score += 30
        @flags << "elevated_order_velocity"
      end
    end

    # Guest order over $500 is higher risk
    def check_high_value_guest!
      if @order.customer_id.nil? && @order.total_price > 500
        @score += 25
        @flags << "high_value_guest_order"
      end
    end

    # Order has existing failed payment attempts
    def check_multiple_failed_payments!
      failed = TenantScoped.with_bypass do
        @order.store.payments
              .where(status: :failed)
              .where("created_at > ?", 24.hours.ago)
              .count
      end

      if failed >= 3
        @score += 30
        @flags << "multiple_recent_payment_failures"
      end
    end

    def check_suspicious_email!
      email = @order.email.to_s.downcase
      disposable_domains = %w[mailinator.com guerrillamail.com tempmail.com 10minutemail.com yopmail.com]

      if disposable_domains.any? { |d| email.ends_with?("@#{d}") }
        @score += 50
        @flags << "disposable_email_domain"
      end
    end

    def risk_recommendation
      if @score >= RISK_THRESHOLDS[:block]  then "block"
      elsif @score >= RISK_THRESHOLDS[:review] then "review"
      else "allow"
      end
    end
  end
end
