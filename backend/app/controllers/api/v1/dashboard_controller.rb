module Api
  module V1
    class DashboardController < ApplicationController
      before_action :require_store_context!

      # GET /api/v1/stores/:store_id/dashboard
      # Query params:
      #   ?period=7d|30d|90d|1y  (default: 30d)
      def metrics
        result = Analytics::StoreDashboard.call(
          store:  Current.store,
          period: params[:period] || "30d"
        )

        render json: result.object, status: :ok
      end
    end
  end
end
