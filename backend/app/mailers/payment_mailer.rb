class PaymentMailer < ApplicationMailer
  def success(payment)
    @payment = payment
    @order   = TenantScoped.with_bypass { payment.order }
    @store   = TenantScoped.with_bypass { payment.store }
    @email   = @order.email

    return unless @email.present?

    mail(
      to:      @email,
      subject: "[#{@store.name}] Payment confirmed — #{@order.order_number}"
    ) do |format|
      format.html { render inline: payment_success_html }
      format.text { render inline: payment_success_text }
    end
  end

  def failed(payment)
    @payment = payment
    @order   = TenantScoped.with_bypass { payment.order }
    @store   = TenantScoped.with_bypass { payment.store }
    @email   = @order.email

    return unless @email.present?

    mail(
      to:      @email,
      subject: "[#{@store.name}] Payment issue — Action required"
    ) do |format|
      format.html { render inline: payment_failed_html }
      format.text { render inline: payment_failed_text }
    end
  end

  private

  def payment_success_html
    <<~HTML
      <!DOCTYPE html><html><body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:20px">
      <h2 style="color:#059669">&#10003; Payment Confirmed</h2>
      <p>Your payment of <strong>#{@payment.currency} #{@payment.amount}</strong> for order <strong>#{@order.order_number}</strong> has been successfully processed.</p>
      <p style="color:#9ca3af;font-size:12px">#{@store.name} &mdash; Powered by Neofy</p>
      </body></html>
    HTML
  end

  def payment_success_text
    "Payment confirmed: #{@payment.currency} #{@payment.amount} for order #{@order.order_number} at #{@store.name}."
  end

  def payment_failed_html
    <<~HTML
      <!DOCTYPE html><html><body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:20px">
      <h2 style="color:#dc2626">&#10007; Payment Failed</h2>
      <p>We were unable to process your payment of <strong>#{@payment.currency} #{@payment.amount}</strong> for order <strong>#{@order.order_number}</strong>.</p>
      <p>Error: #{@payment.error_message}</p>
      <p>Please update your payment method and try again.</p>
      <p style="color:#9ca3af;font-size:12px">#{@store.name} &mdash; Powered by Neofy</p>
      </body></html>
    HTML
  end

  def payment_failed_text
    "Payment failed for order #{@order.order_number}. Error: #{@payment.error_message}. Please try again."
  end
end
