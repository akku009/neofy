require "resolv"

module Domains
  # Verifies domain ownership via DNS TXT record lookup.
  #
  # Verification flow:
  #   1. Store owner adds a domain via Domains::AddDomain
  #   2. System generates a unique verification_token
  #   3. Store owner adds DNS TXT record:
  #        neofy-verification=<verification_token>
  #   4. Store owner calls this service (via POST /domains/:id/verify)
  #   5. Service queries DNS for the TXT record and matches the token
  #
  # DNS propagation can take up to 48h, so verification may need retrying.
  class VerifyDomain < ApplicationService
    DNS_TIMEOUT_SECONDS = 5

    def initialize(domain:)
      @domain = domain
    end

    def call
      return failure("Domain is already verified.") if @domain.verified?
      return failure("Domain has no verification token.") if @domain.verification_token.blank?

      if txt_record_present?
        @domain.mark_verified!
        success(@domain)
      else
        failure(
          "TXT record not found. Please add the following DNS record to #{@domain.domain}:\n" \
          "  Type:  TXT\n" \
          "  Name:  @  (root domain)\n" \
          "  Value: #{@domain.txt_record_value}\n\n" \
          "DNS propagation can take up to 48 hours. Please try again later."
        )
      end
    rescue Resolv::ResolvError => e
      failure("DNS resolution failed for '#{@domain.domain}': #{e.message}")
    rescue => e
      Rails.logger.error("[Domains::VerifyDomain] #{e.class}: #{e.message}")
      failure("Verification error: #{e.message}")
    end

    private

    def txt_record_present?
      expected = @domain.txt_record_value

      Resolv::DNS.open do |dns|
        dns.timeouts = DNS_TIMEOUT_SECONDS
        records = dns.getresources(
          @domain.domain,
          Resolv::DNS::Resource::IN::TXT
        )
        records.any? { |r| r.strings.join == expected }
      end
    end
  end
end
