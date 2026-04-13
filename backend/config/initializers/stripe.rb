Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY") do
  Rails.logger.warn("[Stripe] STRIPE_SECRET_KEY is not set. Payment features will be unavailable.")
  nil
end

# Stripe API version — pin to a specific version for stability.
# When upgrading, review Stripe's changelog for breaking changes.
Stripe.api_version = "2023-10-16"

# Log Stripe API calls in development for debugging.
Stripe.log_level = Stripe::LEVEL_INFO if Rails.env.development?
