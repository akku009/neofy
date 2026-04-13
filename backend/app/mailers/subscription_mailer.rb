class SubscriptionMailer < ApplicationMailer
  def activated(store, subscription)
    @store        = store
    @subscription = subscription
    @plan         = subscription.plan
    @owner_email  = store.user.email

    mail(
      to:      @owner_email,
      subject: "Welcome to Neofy #{@plan.name} — Your trial has started"
    ) do |format|
      format.html { render inline: activated_html }
      format.text { render inline: activated_text }
    end
  end

  def cancelled(store, subscription)
    @store        = store
    @subscription = subscription
    @owner_email  = store.user.email

    mail(
      to:      @owner_email,
      subject: "Your Neofy subscription has been cancelled"
    ) do |format|
      format.html { render inline: cancelled_html }
      format.text { render inline: cancelled_text }
    end
  end

  def payment_failed(store, subscription)
    @store        = store
    @subscription = subscription
    @plan         = subscription.plan
    @owner_email  = store.user.email

    mail(
      to:      @owner_email,
      subject: "Action required: Neofy subscription payment failed"
    ) do |format|
      format.html { render inline: payment_failed_html }
      format.text { render inline: payment_failed_text }
    end
  end

  private

  def activated_html
    <<~HTML
      <!DOCTYPE html><html><body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:20px">
      <h2>Welcome to Neofy #{@plan.name}!</h2>
      <p>Your 14-day free trial for <strong>#{@store.name}</strong> has started.</p>
      <p>Plan: <strong>#{@plan.name}</strong> at #{@subscription.billing_interval == 'yearly' ? "#{@plan.price_yearly}/yr" : "#{@plan.price_monthly}/mo"}</p>
      <p>Trial ends: <strong>#{@subscription.trial_end&.strftime("%B %d, %Y")}</strong></p>
      <p style="color:#9ca3af;font-size:12px">Neofy &mdash; by Neorix Labs</p>
      </body></html>
    HTML
  end

  def activated_text
    "Your Neofy #{@plan.name} trial for #{@store.name} has started. Trial ends #{@subscription.trial_end&.strftime('%B %d, %Y')}."
  end

  def cancelled_html
    <<~HTML
      <!DOCTYPE html><html><body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:20px">
      <h2>Subscription Cancelled</h2>
      <p>Your Neofy subscription for <strong>#{@store.name}</strong> has been cancelled.</p>
      <p>Your store will remain accessible until the end of the current billing period.</p>
      <p style="color:#9ca3af;font-size:12px">Neofy &mdash; by Neorix Labs</p>
      </body></html>
    HTML
  end

  def cancelled_text
    "Your Neofy subscription for #{@store.name} has been cancelled."
  end

  def payment_failed_html
    <<~HTML
      <!DOCTYPE html><html><body style="font-family:sans-serif;max-width:600px;margin:0 auto;padding:20px">
      <h2 style="color:#dc2626">Action Required: Payment Failed</h2>
      <p>We were unable to process your Neofy subscription payment for <strong>#{@store.name}</strong>.</p>
      <p>Please update your payment method in the Neofy dashboard to keep your store active.</p>
      <p style="color:#9ca3af;font-size:12px">Neofy &mdash; by Neorix Labs</p>
      </body></html>
    HTML
  end

  def payment_failed_text
    "Subscription payment failed for #{@store.name}. Please update your payment method in Neofy."
  end
end
