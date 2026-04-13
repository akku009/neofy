class OrderMailer < ApplicationMailer
  # Send order confirmation to the customer.
  # Called from OrderProcessingJob after checkout.
  def confirmation(order)
    @order      = order
    @store      = TenantScoped.with_bypass { order.store }
    @customer   = order.customer
    @items      = order.order_items.includes(:variant)
    @email      = order.email || @customer&.email

    return unless @email.present?

    mail(
      to:      @email,
      subject: "[#{@store.name}] Order Confirmed — #{@order.order_number}"
    ) do |format|
      format.html { render inline: order_confirmation_html }
      format.text { render inline: order_confirmation_text }
    end
  end

  private

  def order_confirmation_html
    items_rows = @items.map do |item|
      "<tr><td style='padding:8px'>#{item.title} &mdash; #{item.variant_title}</td>" \
      "<td style='padding:8px;text-align:right'>#{@order.currency} #{item.price} x #{item.quantity}</td></tr>"
    end.join

    <<~HTML
      <!DOCTYPE html><html><body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:20px">
      <h2>Thank you for your order!</h2>
      <p>Hi#{@customer ? " #{@customer.first_name}" : ""},</p>
      <p>Your order <strong>#{@order.order_number}</strong> has been confirmed at <strong>#{@store.name}</strong>.</p>
      <table width="100%" border="0" cellpadding="0" cellspacing="0" style="border:1px solid #eee;border-radius:8px;overflow:hidden;margin:20px 0">
        <thead><tr style="background:#f9fafb"><th style="padding:8px;text-align:left">Item</th><th style="padding:8px;text-align:right">Price</th></tr></thead>
        <tbody>#{items_rows}</tbody>
        <tfoot><tr style="border-top:1px solid #eee;font-weight:bold"><td style="padding:8px">Total</td><td style="padding:8px;text-align:right">#{@order.currency} #{@order.total_price}</td></tr></tfoot>
      </table>
      <p style="color:#6b7280;font-size:13px">You will receive a shipping notification once your order is on its way.</p>
      <hr style="border:none;border-top:1px solid #eee;margin:20px 0">
      <p style="color:#9ca3af;font-size:12px">#{@store.name} &mdash; Powered by Neofy</p>
      </body></html>
    HTML
  end

  def order_confirmation_text
    lines = @items.map { |i| "- #{i.title} (#{i.variant_title}) x#{i.quantity} — #{@order.currency} #{i.price}" }
    <<~TEXT
      Thank you for your order!

      Order #{@order.order_number} confirmed at #{@store.name}.

      Items:
      #{lines.join("\n")}

      Total: #{@order.currency} #{@order.total_price}

      ---
      #{@store.name}
    TEXT
  end
end
