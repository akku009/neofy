module Domains
  class SetPrimaryDomain < ApplicationService
    def initialize(domain:, store:)
      @domain = domain
      @store  = store
    end

    def call
      # Only allow setting a verified domain as primary
      unless @domain.verified?
        return failure("Domain must be verified before it can be set as primary.")
      end

      unless @domain.store_id == @store.id
        return failure("Domain does not belong to this store.")
      end

      ActiveRecord::Base.transaction do
        # Clear primary from all other domains in this store
        TenantScoped.with_bypass do
          Domain.where(store_id: @store.id).where.not(id: @domain.id).update_all(primary: false)
        end

        @domain.update!(primary: true)
      end

      success(@domain)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end
  end
end
