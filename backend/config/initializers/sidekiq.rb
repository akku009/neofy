redis_config = {
  url:            ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
  connect_timeout: 2,
  read_timeout:    1,
  write_timeout:   1,
}

Sidekiq.configure_server do |config|
  config.redis       = redis_config
  config.concurrency = ENV.fetch("SIDEKIQ_CONCURRENCY", 5).to_i

  config.death_handlers << lambda do |job, ex|
    Rails.logger.error("[Sidekiq] Job permanently failed: #{job['class']} (#{ex.class}: #{ex.message})")
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
