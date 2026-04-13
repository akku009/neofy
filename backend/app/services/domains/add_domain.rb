module Domains
  class AddDomain < ApplicationService
    def initialize(store:, domain_str:)
      @store      = store
      @domain_str = domain_str.to_s.downcase.strip.delete_prefix("www.")
    end

    def call
      # Guard: reject platform-owned domains
      if Domain::RESERVED_DOMAINS.include?(@domain_str)
        return failure("'#{@domain_str}' is a reserved platform domain and cannot be claimed.")
      end

      # Guard: reject domains already verified by another store
      existing = TenantScoped.with_bypass { Domain.find_by(domain: @domain_str) }
      if existing && existing.store_id != @store.id
        return failure("'#{@domain_str}' is already registered to another store.")
      end

      domain = TenantScoped.with_bypass do
        Domain.create!(
          store_id: @store.id,
          domain:   @domain_str,
          verified: false,
          primary:  false
        )
      end

      success(domain)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end
  end
end
