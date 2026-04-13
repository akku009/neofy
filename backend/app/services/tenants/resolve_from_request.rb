module Tenants
  # Resolves the tenant (Store) from an incoming HTTP request.
  #
  # Resolution priority order:
  #   1. X-Store-Subdomain request header (explicit override for API/mobile clients)
  #   2. Custom domain lookup  (e.g. mystore.com → Domain record → Store)
  #   3. Subdomain pattern     (e.g. my-store.neofy.com → Store.subdomain = "my-store")
  #
  # Returns a Store record on success, nil if no tenant can be resolved.
  #
  # Used by both ApplicationController (JSON API) and StorefrontController (HTML).
  # Centralising here ensures custom-domain support is identical in both paths.
  class ResolveFromRequest
    # Hosts that belong to the platform itself — never treated as custom domains.
    PLATFORM_TLD = %w[neofy.com lvh.me localhost].freeze
    IGNORED_SUBDOMAINS = %w[www api admin app].freeze

    def self.call(request)
      new(request).call
    end

    def initialize(request)
      @request = request
    end

    def call
      header_store     ||
        custom_domain_store ||
        subdomain_store
    end

    private

    # ── 1. Explicit header override ──────────────────────────────────────────────
    # Allows API clients and mobile apps to declare which store they're targeting
    # without needing a subdomain on the request host.
    def header_store
      subdomain = @request.headers["X-Store-Subdomain"].presence
      return nil unless subdomain

      TenantScoped.with_bypass do
        Store.find_by(subdomain: subdomain.downcase.strip, status: :active)
      end
    end

    # ── 2. Custom domain lookup ──────────────────────────────────────────────────
    # Only attempted when the request host is NOT a platform-owned host.
    # Looks up the Domain table for a verified, active-store match.
    def custom_domain_store
      host = normalized_host
      return nil if platform_host?(host)

      domain_record = TenantScoped.with_bypass do
        Domain.joins(:store)
              .where(domains: { domain: host, verified: true })
              .where(stores:  { status: :active })
              .first
      end

      domain_record&.store
    end

    # ── 3. Subdomain pattern ─────────────────────────────────────────────────────
    # e.g. my-store.neofy.com → subdomain = "my-store"
    # e.g. my-store.lvh.me:3000 → subdomain = "my-store"
    def subdomain_store
      subdomain = extract_subdomain
      return nil unless subdomain.present?

      TenantScoped.with_bypass do
        Store.find_by(subdomain: subdomain, status: :active)
      end
    end

    # ── Host helpers ─────────────────────────────────────────────────────────────

    def normalized_host
      @normalized_host ||= @request.host.downcase.strip
    end

    # Returns true if the host is a platform-owned host.
    # These should NEVER be looked up in the custom Domain table.
    def platform_host?(host)
      PLATFORM_TLD.any? { |tld| host == tld || host.end_with?(".#{tld}") }
    end

    def extract_subdomain
      host  = normalized_host
      parts = host.split(".")

      # Need at least 3 parts to have a subdomain (e.g. store.neofy.com)
      return nil if parts.length <= 2

      candidate = parts.first
      return nil if IGNORED_SUBDOMAINS.include?(candidate)

      candidate
    end
  end
end
