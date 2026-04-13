require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading                   = true
  config.eager_load                         = false
  config.consider_all_requests_local        = true
  config.server_timing                      = true
  config.cache_store                        = :redis_cache_store, { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }
  config.active_support.deprecation         = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_record.migration_error      = :page_load
  config.active_record.verbose_query_logs   = true
  config.log_level                          = :debug

  # ── Subdomain support in development ─────────────────────────────────────────
  # Use lvh.me which resolves all subdomains to 127.0.0.1.
  # e.g. my-store.lvh.me:3000 → subdomain = "my-store"
  #
  # No /etc/hosts edits needed — lvh.me is a public wildcard DNS.
  config.hosts << /.*\.lvh\.me/

  # Also allow plain localhost
  config.hosts << "localhost"

  # Mailer
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching       = false
  config.action_mailer.default_url_options   = { host: "localhost", port: 3000 }
end
