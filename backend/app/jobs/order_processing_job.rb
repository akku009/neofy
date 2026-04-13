class OrderProcessingJob < ApplicationJob
  queue_as :orders

  # Async post-checkout finalization.
  #
  # NOTE: Inventory deduction is performed synchronously in Checkout::CreateOrder
  # (within the checkout transaction, with FOR UPDATE locks). This job must NOT
  # deduct inventory again.
  #
  # Responsibilities:
  #   1. Sync customer aggregated stats (orders_count, total_spent)
  #   2. Future: send order confirmation email
  #   3. Future: trigger post-purchase webhooks
  #
  # Usage:
  #   OrderProcessingJob.perform_later(order.id)
  def perform(order_id)
    order = TenantScoped.with_bypass { Order.with_deleted.find_by(id: order_id) }

    unless order
      Rails.logger.warn("[OrderProcessingJob] Order #{order_id} not found — skipping")
      return
    end

    run_fraud_check!(order)
    sync_customer_stats!(order)
    OrderMailer.confirmation(order).deliver_later

    Rails.logger.info(
      "[OrderProcessingJob] Finalized order #{order.order_number} " \
      "(store=#{order.store_id}, total=#{order.total_price} #{order.currency})"
    )
  end

  private

  def run_fraud_check!(order)
    result = Fraud::CheckOrder.call(order: order)
    return unless result.success?

    if result.object[:recommendation] == "block"
      Rails.logger.warn("[OrderProcessingJob] FRAUD BLOCKED order #{order.order_number} (score=#{result.object[:risk_score]})")
    end
  end

  # Denormalize orders_count + total_spent onto the Customer record.
  # Uses increment! for atomic updates — safe under concurrent job execution.
  def sync_customer_stats!(order)
    return unless order.customer_id

    customer = TenantScoped.with_bypass do
      Customer.with_deleted.find_by(id: order.customer_id)
    end
    return unless customer

    customer.with_lock do
      customer.increment!(:orders_count)
      customer.increment!(:total_spent, order.total_price)
    end
  end
end
