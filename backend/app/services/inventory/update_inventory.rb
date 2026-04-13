module Inventory
  class UpdateInventory < ApplicationService
    ADJUSTMENTS = %w[set increment decrement].freeze

    # adjustment:
    #   "set"       — replace inventory_quantity with :quantity
    #   "increment" — add :quantity to current stock
    #   "decrement" — subtract :quantity from current stock
    def initialize(variant:, quantity:, adjustment: "set")
      @variant    = variant
      @quantity   = quantity.to_i
      @adjustment = adjustment.to_s
    end

    def call
      return failure("Invalid adjustment '#{@adjustment}'. Must be: #{ADJUSTMENTS.join(', ')}") \
        unless ADJUSTMENTS.include?(@adjustment)

      new_qty = resolved_quantity

      if new_qty.negative? && @variant.inventory_policy_deny?
        return failure(
          "Insufficient inventory. Current: #{@variant.inventory_quantity}, " \
          "requested change would result in #{new_qty}."
        )
      end

      @variant.update!(inventory_quantity: [new_qty, 0].max)
      success(@variant)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    def resolved_quantity
      case @adjustment
      when "set"       then @quantity
      when "increment" then @variant.inventory_quantity + @quantity
      when "decrement" then @variant.inventory_quantity - @quantity
      end
    end
  end
end
