module Checkout
  class CreateOrder < ApplicationService
    # Domain error — represents an expected checkout failure, not a programming bug.
    # Controllers catch this via the ServiceResult failure path, not exception handling.
    class CheckoutError < StandardError; end

    def initialize(store:, params:, current_user: nil)
      @store        = store
      @params       = params.to_h.with_indifferent_access
      @current_user = current_user
    end

    def call
      committed_order = nil

      ActiveRecord::Base.transaction do
        customer   = resolve_customer
        line_items = validate_and_lock_line_items!
        order      = persist_order!(customer, line_items)
        deduct_inventory!(line_items)
        committed_order = order
      end

      # Enqueue AFTER the transaction commits.
      # If enqueued inside the transaction, Sidekiq could process the job
      # before the commit is visible, or the transaction could roll back
      # after the job is already in Redis.
      OrderProcessingJob.perform_later(committed_order.id)

      success(committed_order.reload)
    rescue CheckoutError => e
      failure(e.message)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    # ── Customer resolution ─────────────────────────────────────────────────────
    # Supports both:
    #   a) Authenticated store owner creating orders for customers
    #   b) Guest checkout — finds or creates a Customer record
    def resolve_customer
      cparams = @params[:customer]
      return nil unless cparams.present?

      email = cparams[:email].to_s.strip.downcase
      raise CheckoutError, "Customer email is required" if email.blank?

      # Rescue unique constraint violation from concurrent checkouts with the same email.
      TenantScoped.with_bypass do
        Customer.find_or_create_by!(store_id: @store.id, email: email) do |c|
          c.first_name = cparams[:first_name]
          c.last_name  = cparams[:last_name]
          c.phone      = cparams[:phone]
        end
      rescue ActiveRecord::RecordNotUnique
        Customer.find_by!(store_id: @store.id, email: email)
      end
    end

    # ── Item validation + row-level locking ────────────────────────────────────
    # Uses SELECT ... FOR UPDATE to acquire exclusive row locks on each variant
    # before reading inventory. This prevents the classic TOCTOU race condition
    # where two concurrent checkouts both see sufficient stock and both proceed.
    #
    # Lock order: variants sorted by UUID string to prevent deadlocks when two
    # concurrent transactions try to lock the same set of variants.
    MAX_QUANTITY_PER_ITEM = 1_000   # Prevent DoS / inventory bomb attacks
    MAX_LINE_ITEMS        = 250     # Prevent degenerate cart size

    def validate_and_lock_line_items!
      raw_items = Array(@params[:items])
      raise CheckoutError, "Order must contain at least one item" if raw_items.empty?
      raise CheckoutError, "Order exceeds maximum item count" if raw_items.size > MAX_LINE_ITEMS

      # Merge duplicate variant_ids (e.g. same item added twice on frontend)
      merged_items = raw_items.each_with_object({}) do |item, acc|
        vid        = item[:variant_id].to_s
        acc[vid]   = (acc[vid] || 0) + item[:quantity].to_i
      end

      # Sort by variant_id for consistent lock acquisition order (deadlock prevention)
      merged_items.sort_by { |vid, _| vid }.map do |variant_id, quantity|
        raise CheckoutError, "Quantity must be greater than 0" unless quantity.positive?
        raise CheckoutError, "Quantity #{quantity} exceeds maximum allowed (#{MAX_QUANTITY_PER_ITEM})" \
          if quantity > MAX_QUANTITY_PER_ITEM

        # Lock the variant row exclusively for the duration of this transaction.
        # The store_id filter is our tenant isolation gate — no bypass of security.
        variant = TenantScoped.with_bypass do
          Variant.where(id: variant_id, store_id: @store.id).lock.first
        end

        if variant.nil?
          raise CheckoutError,
            "Variant '#{variant_id}' not found or does not belong to this store"
        end

        if variant.inventory_policy_deny? && variant.inventory_quantity < quantity
          raise CheckoutError,
            "'#{variant.title}' has insufficient stock. " \
            "Available: #{variant.inventory_quantity}, requested: #{quantity}."
        end

        { variant: variant, quantity: quantity }
      end
    end

    # ── Order + OrderItems persistence ─────────────────────────────────────────
    def persist_order!(customer, line_items)
      subtotal = line_items.sum { |i| i[:variant].price * i[:quantity] }

      # Apply discount code if provided — validated and locked server-side only.
      discount_result = apply_discount_locked!(subtotal)
      discount_amount = discount_result[:amount]
      discount_obj    = discount_result[:discount]

      total_price = subtotal - discount_amount

      order = @store.orders.create!(
        customer:           customer,
        email:              resolve_email(customer),
        currency:           @store.currency,
        subtotal_price:     subtotal,
        total_tax:          BigDecimal("0"),
        total_discounts:    discount_amount,
        total_price:        total_price,
        discount_code:      discount_obj&.code,
        financial_status:   :pending,
        fulfillment_status: :unfulfilled,
        processed_at:       Time.current,
        shipping_address:   @params[:shipping_address],
        billing_address:    @params[:billing_address],
        note:               @params[:note]
      )

      line_items.each { |item| build_order_item!(order, item) }

      # Atomically increment usage count now that the order and items are persisted.
      discount_obj&.increment_usage!

      order
    end

    def build_order_item!(order, item)
      variant = item[:variant]
      product = TenantScoped.with_bypass { Product.find_by(id: variant.product_id) }

      order.order_items.create!(
        store_id:           @store.id,
        variant:            variant,
        product:            product,
        # ── Price snapshot — never re-read from variant after this point ────────
        title:              product&.title || variant.display_name,
        variant_title:      variant.title,
        sku:                variant.sku,
        image_url:          variant.image_url,
        quantity:           item[:quantity],
        price:              variant.price,       # Snapshot at purchase time
        total_discount:     BigDecimal("0"),
        taxable:            variant.taxable,
        requires_shipping:  variant.requires_shipping,
        fulfillment_status: :unfulfilled
      )
    end

    # ── Inventory deduction ─────────────────────────────────────────────────────
    # Runs AFTER order is persisted — inside the same transaction.
    # If any decrement fails, the whole transaction rolls back (order is not created).
    def deduct_inventory!(line_items)
      line_items.each do |item|
        variant = item[:variant]
        next if variant.inventory_policy_continue?  # oversell allowed

        result = Inventory::UpdateInventory.call(
          variant:    variant,
          quantity:   item[:quantity],
          adjustment: "decrement"
        )

        raise CheckoutError, result.errors.join(", ") if result.failure?
      end
    end

    # ── Discount application (with row lock) ────────────────────────────────────
    # Acquires a FOR UPDATE lock on the discount row to prevent concurrent checkouts
    # from bypassing the usage_limit check simultaneously.
    def apply_discount_locked!(subtotal)
      code = @params[:discount_code].to_s.upcase.strip
      return { amount: BigDecimal("0"), discount: nil } if code.blank?

      discount = TenantScoped.with_bypass do
        Discount.where(store_id: @store.id, code: code).lock.first
      end

      unless discount&.applicable?(subtotal)
        raise CheckoutError, "Discount code '#{code}' is invalid or cannot be applied to this order"
      end

      amount = discount.calculate_discount(subtotal)
      { amount: amount, discount: discount }
    end

    def resolve_email(customer)
      customer&.email || @params.dig(:customer, :email).presence || @current_user&.email
    end
  end
end
