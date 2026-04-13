Rails.application.config.action_dispatch.default_headers = {
  "X-Frame-Options"        => "DENY",
  "X-Content-Type-Options" => "nosniff",
  "X-XSS-Protection"       => "1; mode=block",
  "Referrer-Policy"         => "strict-origin-when-cross-origin",
  "Permissions-Policy"      => "camera=(), microphone=(), geolocation=()",
  "X-Download-Options"      => "noopen",
  "X-Permitted-Cross-Domain-Policies" => "none"
}

# Remove Server and X-Powered-By headers in production to reduce fingerprinting
if Rails.env.production?
  Rails.application.config.middleware.insert_before(
    ActionDispatch::Static,
    Rack::Deflater
  ) rescue nil
end
