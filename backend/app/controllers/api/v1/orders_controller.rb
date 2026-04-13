module Api
  module V1
    class OrdersController < ApplicationController
      before_action :require_store_context!
      before_action :set_order, only: %i[show cancel fulfill payment_intent]

      # GET /api/v1/stores/:store_id/orders
      # Supports filtering: ?financial_status=paid&fulfillment_status=unfulfilled
      def index
        authorize Order, :index?

        orders = Current.store.orders
                        .includes(:customer, :payment, order_items: [:variant])
                        .filter_by_financial_status(params[:financial_status])
                        .filter_by_fulfillment_status(params[:fulfillment_status])
                        .order(created_at: :desc)
                        .page(params[:page])
                        .per(params[:per_page] || 20)

        render json: {
          orders: serialize_collection(orders, OrderSerializer),
          meta:   pagination_meta(orders)
        }
      end

      # GET /api/v1/stores/:store_id/orders/:id
      def show
        authorize @order
        render json: @order, serializer: OrderSerializer
      end

      # POST /api/v1/stores/:store_id/orders
      # Checkout endpoint — creates order + atomically deducts inventory.
      #
      # Expected payload:
      #   {
      #     "order": {
      #       "customer": { "email": "...", "first_name": "...", "last_name": "..." },
      #       "items": [{ "variant_id": "uuid", "quantity": 2 }],
      #       "shipping_address": { "address1": "...", "city": "...", ... },
      #       "note": "..."
      #     }
      #   }
      def create
        authorize Order, :create?

        result = Checkout::CreateOrder.call(
          store:        Current.store,
          params:       checkout_params,
          current_user: current_user
        )

        if result.success?
          render json: result.object, serializer: OrderSerializer, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/stores/:store_id/orders/:id/cancel
      def cancel
        authorize @order, :cancel?

        result = Orders::CancelOrder.call(
          order:  @order,
          reason: params[:reason]
        )

        if result.success?
          render json: result.object, serializer: OrderSerializer
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/stores/:store_id/orders/:id/fulfill
      def fulfill
        authorize @order, :fulfill?

        if @order.financial_status_paid?
          @order.update!(fulfillment_status: :fulfilled)
          render json: @order.reload, serializer: OrderSerializer
        else
          render json: { errors: ["Cannot fulfill an unpaid order"] },
                 status: :unprocessable_entity
        end
      end

      # POST /api/v1/stores/:store_id/orders/:id/payment_intent
      # Creates a Stripe PaymentIntent and returns the client_secret for the frontend.
      # The frontend uses Stripe.js to confirm the payment with this secret.
      def payment_intent
        authorize @order, :payment_intent?

        result = Payments::CreatePaymentIntent.call(
          order: @order,
          store: Current.store
        )

        if result.success?
          render json: {
            client_secret: result.object[:client_secret],
            payment:       PaymentSerializer.new(result.object[:payment]).as_json
          }, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      def set_order
        @order = Current.store.orders.includes(:customer, :order_items).find(params[:id])
      end

      def checkout_params
        params.require(:order).permit(
          :note,
          customer:         %i[email first_name last_name phone],
          items:            %i[variant_id quantity],
          shipping_address: %i[first_name last_name address1 address2 city province country zip phone],
          billing_address:  %i[first_name last_name address1 address2 city province country zip phone]
        )
      end

      def serialize_collection(collection, serializer_class)
        ActiveModelSerializers::SerializableResource.new(
          collection,
          each_serializer: serializer_class
        ).as_json
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
