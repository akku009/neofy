Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]

  # Only report errors in production and staging
  config.enabled_environments = %w[production staging]

  # Send 20% of transactions as performance traces
  config.traces_sample_rate = 0.2

  # Attach request data to all events
  config.send_default_pii = false  # Don't send PII (emails, IPs) unless explicitly needed

  # Breadcrumbs from Rails logger
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  config.before_send = lambda do |event, _hint|
    # Strip sensitive params from Sentry events
    if event.request
      event.request.data&.delete("password")
      event.request.data&.delete("credit_card")
    end
    event
  end
end
