class Rack::Attack
  # ── IP resolution ─────────────────────────────────────────────────────────────
  # In production, Nginx adds the real client IP as the LAST entry in X-Forwarded-For.
  # We use the LAST hop (set by our trusted proxy) not the FIRST (attacker-controlled).
  # Without this, attackers can spoof X-Forwarded-For: 1.2.3.4 to bypass throttling.
  def self.real_ip(req)
    forwarded_for = req.env["HTTP_X_FORWARDED_FOR"]
    if forwarded_for.present? && Rails.env.production?
      # Use last IP added by our trusted Nginx proxy
      forwarded_for.split(",").last.strip
    else
      req.ip
    end
  end

  # ── 1. Throttle all API requests by IP: 120/min ───────────────────────────────
  throttle("api/ip", limit: 120, period: 60.seconds) do |req|
    real_ip(req) if req.path.start_with?("/api/")
  end

  # ── 2. Throttle by JWT bearer token: 300/min ─────────────────────────────────
  throttle("api/token", limit: 300, period: 60.seconds) do |req|
    token = req.get_header("HTTP_AUTHORIZATION")&.delete_prefix("Bearer ")&.strip
    token.presence if req.path.start_with?("/api/")
  end

  # ── 3. Strict login throttle: 5 attempts / 20s per IP+email ──────────────────
  throttle("auth/login/ip_email", limit: 5, period: 20.seconds) do |req|
    if req.path.include?("/sign_in") && req.post?
      email = req.params.dig("user", "email").to_s.downcase.strip
      "#{real_ip(req)}:#{email}" if email.present?
    end
  end

  # ── 4. Storefront throttle: 60 HTML requests/min per IP ───────────────────────
  throttle("storefront/ip", limit: 60, period: 60.seconds) do |req|
    real_ip(req) unless req.path.start_with?("/api/")
  end

  # ── 5. Checkout throttle: 10 attempts/min per IP ──────────────────────────────
  # Prevents rapid-fire checkout abuse (concurrent order bombing)
  throttle("checkout/ip", limit: 10, period: 60.seconds) do |req|
    real_ip(req) if req.path == "/checkout" && req.post?
  end

  # ── 6. Storefront login throttle: 5 attempts / 30s per IP ─────────────────────
  throttle("storefront/login", limit: 5, period: 30.seconds) do |req|
    real_ip(req) if req.path == "/account/login" && req.post?
  end

  # ── 7. Cart spam throttle: 30 cart adds/min per IP ────────────────────────────
  throttle("storefront/cart_add", limit: 30, period: 60.seconds) do |req|
    real_ip(req) if req.path == "/cart/items" && req.post?
  end

  # ── Blocklist: block IPs explicitly banned (via Redis) ────────────────────────
  blocklist("blocked/ip") do |req|
    Rack::Attack.cache.read("blocked_ip:#{real_ip(req)}")
  end

  # ── Response for throttled requests ──────────────────────────────────────────
  self.throttled_responder = lambda do |req|
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      {
        "Content-Type"  => "application/json",
        "Retry-After"   => retry_after.to_s
      },
      [{ error: "Rate limit exceeded. Retry after #{retry_after} seconds." }.to_json]
    ]
  end

  self.blocklisted_responder = lambda do |_req|
    [403, { "Content-Type" => "application/json" }, [{ error: "Forbidden" }.to_json]]
  end
end

# Use Redis for distributed rate limiting (same Redis as Sidekiq)
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url:       ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
  namespace: "rack_attack"
)
