Rails.application.configure do
  config.lograge.enabled   = !Rails.env.test?
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.base_controller_class = %w[
    ActionController::API
    ActionController::Base
  ]

  # Ignore health check noise
  config.lograge.ignore_actions = ["HealthController#show"]

  # Append custom fields to every log line
  config.lograge.custom_options = lambda do |event|
    {
      request_id: Current.request_id,
      store_id:   Current.store&.id,
      user_id:    Current.user&.id,
      host:       event.payload[:host],
      params:     event.payload[:params]
                       &.except("controller", "action", "format", "_method", "password")
    }.compact
  end
end
