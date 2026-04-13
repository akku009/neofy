require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading  = false
  config.eager_load        = true
  config.consider_all_requests_local = false
  config.log_level         = :info
  config.log_tags          = [:request_id]

  # ── Database / Caching ────────────────────────────────────────────────────────
  config.cache_store = :redis_cache_store, {
    url:               ENV.fetch("REDIS_URL", "redis://localhost:6379/1"),
    expires_in:        1.hour,
    namespace:         "neofy_cache",
    error_handler:     lambda { |method:, returning:, exception:|
      Rails.logger.warn("[Cache] Error on #{method}: #{exception.class}: #{exception.message}")
    }
  }

  # ── Background Jobs ───────────────────────────────────────────────────────────
  config.active_job.queue_adapter = :sidekiq

  # ── Host allowlist ────────────────────────────────────────────────────────────
  # In production, requests arrive through Nginx which has already validated the
  # host. We allow all hosts here so custom tenant domains work correctly.
  # Nginx is responsible for filtering invalid hosts at the network layer.
  config.hosts = :all

  # ── Reverse proxy / SSL ───────────────────────────────────────────────────────
  # Nginx terminates SSL and passes X-Forwarded-* headers.
  # Rails must trust the proxy to correctly interpret HTTPS, client IP, etc.
  config.assume_ssl           = true   # Trust X-Forwarded-Proto: https from proxy
  config.force_ssl            = false  # SSL enforced at Nginx level, not Rails
  config.action_dispatch.trusted_proxies = [
    "127.0.0.1",             # Localhost (nginx on same machine)
    "::1",                    # IPv6 loopback
    *ENV.fetch("TRUSTED_PROXIES", "").split(",").map(&:strip)
  ]

  # ── Logging ───────────────────────────────────────────────────────────────────
  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  config.active_record.dump_schema_after_migration = false

  # ── Mailer ────────────────────────────────────────────────────────────────────
  config.action_mailer.raise_delivery_errors     = true
  config.action_mailer.perform_caching           = false
  config.action_mailer.delivery_method           = :smtp
  config.action_mailer.smtp_settings             = {
    address:              ENV.fetch("SMTP_HOST",     "smtp.sendgrid.net"),
    port:                 ENV.fetch("SMTP_PORT",     587).to_i,
    user_name:            ENV["SMTP_USERNAME"],
    password:             ENV["SMTP_PASSWORD"],
    authentication:       :plain,
    enable_starttls_auto: true
  }
  config.action_mailer.default_url_options = {
    host:     ENV.fetch("APP_HOST", "neofy.com"),
    protocol: "https"
  }
end
