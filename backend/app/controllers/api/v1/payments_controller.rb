module Api
  module V1
    class PaymentsController < ApplicationController
      before_action :require_store_context!
      before_action :set_payment, only: %i[show]

      # GET /api/v1/stores/:store_id/payments
      def index
        authorize Payment, :index?

        payments = Current.store.payments
                          .includes(:order)
                          .order(created_at: :desc)
                          .page(params[:page])
                          .per(params[:per_page] || 20)

        render json: {
          payments: ActiveModelSerializers::SerializableResource.new(
            payments,
            each_serializer: PaymentSerializer
          ).as_json,
          meta: pagination_meta(payments)
        }
      end

      # GET /api/v1/stores/:store_id/payments/:id
      def show
        authorize @payment
        render json: @payment, serializer: PaymentSerializer
      end

      private

      def set_payment
        @payment = Current.store.payments.find(params[:id])
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages:  collection.total_pages,
          total_count:  collection.total_count,
          per_page:     collection.limit_value
        }
      end
    end
  end
end
