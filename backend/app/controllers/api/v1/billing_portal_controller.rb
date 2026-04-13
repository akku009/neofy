module Api
  module V1
    class BillingPortalController < ApplicationController
      before_action :require_store_context!

      # POST /api/v1/stores/:store_id/billing_portal
      # Returns a Stripe Billing Portal URL for managing payment methods + invoices.
      def create
        result = Billing::CreateBillingPortalSession.call(
          store:      Current.store,
          return_url: params[:return_url] || "#{ENV.fetch('FRONTEND_URL', 'https://app.neofy.com')}/stores/#{Current.store.id}/settings/billing"
        )

        if result.success?
          render json: { url: result.object[:url] }
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end
    end
  end
end
