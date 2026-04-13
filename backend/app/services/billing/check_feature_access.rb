module Billing
  # Checks whether a store's current plan allows a specific feature or quantity.
  #
  # Usage:
  #   # Boolean feature
  #   Billing::CheckFeatureAccess.call(store: store, feature: :custom_domain)
  #
  #   # Quantity limit (e.g. max_products)
  #   Billing::CheckFeatureAccess.call(store: store, feature: :max_products, current_count: 47)
  #
  class CheckFeatureAccess < ApplicationService
    def initialize(store:, feature:, current_count: nil)
      @store         = store
      @feature       = feature.to_s
      @current_count = current_count
    end

    # Hardcoded fallback limits when the Free plan is not yet seeded.
    # This MUST match Plan::FREE_FEATURES exactly.
    # Never fail open — always enforce limits.
    HARDCODED_FREE_LIMITS = {
      "max_products"    => 10,
      "max_staff"       => 1,
      "custom_domain"   => false,
      "analytics"       => false,
      "api_rate_limit"  => 100
    }.freeze

    def call
      plan = @store.active_plan || free_plan

      limit = if plan
                plan.feature(@feature)
              else
                # Free plan not seeded yet — apply hardcoded minimum limits.
                Rails.logger.warn("[CheckFeatureAccess] Free plan not found — applying hardcoded limits")
                HARDCODED_FREE_LIMITS[@feature]
              end

      # nil limit → feature not defined in plan → deny
      return failure(denied_message(plan)) if limit.nil?

      # -1 (UNLIMITED) → always allow
      return success if limit == Plan::UNLIMITED

      # Boolean feature
      if @current_count.nil?
        return limit ? success : failure(denied_message(plan))
      end

      # Quantity check
      if @current_count.to_i >= limit.to_i
        failure("Your #{plan_name(plan)} plan allows a maximum of #{limit} #{@feature.humanize.downcase}. " \
                "Please upgrade to add more.")
      else
        success
      end
    end

    private

    def plan_name(plan)
      plan&.name || "Free"
    end

    def denied_message(plan)
      "Your #{plan_name(plan)} plan does not include #{@feature.humanize.downcase}. Please upgrade."
    end

    # Fall back to the seeded Free plan when there is no active subscription.
    def free_plan
      @free_plan ||= TenantScoped.with_bypass { Plan.find_by(name: "Free") }
    end
  end
end
