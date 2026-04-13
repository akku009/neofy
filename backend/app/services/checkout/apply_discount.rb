module Checkout
  class ApplyDiscount < ApplicationService
    def initialize(store:, code:, order_total:)
      @store       = store
      @code        = code.to_s.upcase.strip
      @order_total = order_total
    end

    def call
      return failure("Discount code is required") if @code.blank?

      discount = TenantScoped.with_bypass do
        Discount.where(store_id: @store.id).active_now.find_by(code: @code)
      end

      return failure("Discount code '#{@code}' is not valid") unless discount
      return failure("Discount code '#{@code}' is not applicable to this order") \
        unless discount.applicable?(@order_total)

      discount_amount = discount.calculate_discount(@order_total)
      success({ discount: discount, amount: discount_amount })
    end
  end
end
