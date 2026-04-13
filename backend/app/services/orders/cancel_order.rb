module Orders
  class CancelOrder < ApplicationService
    # Only these financial statuses can be cancelled.
    # Paid orders require a refund flow (Step 5), not a simple cancel.
    CANCELLABLE_STATUSES = %w[pending authorized].freeze

    def initialize(order:, reason: "other")
      @order  = order
      @reason = reason.to_s
    end

    def call
      unless CANCELLABLE_STATUSES.include?(@order.financial_status)
        return failure(
          "Cannot cancel an order with status '#{@order.financial_status}'. " \
          "Only #{CANCELLABLE_STATUSES.join(' or ')} orders can be cancelled."
        )
      end

      ActiveRecord::Base.transaction do
        restore_inventory!
        @order.update!(
          financial_status: :voided,
          cancelled_at:     Time.current,
          cancel_reason:    sanitized_cancel_reason
        )
      end

      success(@order.reload)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    # Restore inventory for every order item that has a tracked variant.
    # Uses FOR UPDATE lock to prevent concurrent modifications.
    def restore_inventory!
      @order.order_items.each do |item|
        next unless item.variant_id

        variant = TenantScoped.with_bypass do
          Variant.where(id: item.variant_id).lock.first
        end

        next unless variant
        next if variant.inventory_policy_continue?

        Inventory::UpdateInventory.call(
          variant:    variant,
          quantity:   item.quantity,
          adjustment: "increment"
        )
      end
    end

    def sanitized_cancel_reason
      valid = Order.cancel_reasons.keys
      valid.include?(@reason) ? @reason.to_sym : :other
    end
  end
end
