module Api
  module V1
    class DiscountsController < ApplicationController
      before_action :require_store_context!
      before_action :set_discount, only: %i[show update destroy]

      # GET /api/v1/stores/:store_id/discounts
      def index
        discounts = TenantScoped.with_bypass do
          Current.store.discounts.order(created_at: :desc).page(params[:page]).per(20)
        end
        render json: discounts
      end

      # GET /api/v1/stores/:store_id/discounts/:id
      def show
        render json: @discount
      end

      # POST /api/v1/stores/:store_id/discounts
      def create
        discount = TenantScoped.with_bypass do
          Current.store.discounts.create!(discount_params)
        end
        render json: discount, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # PATCH /api/v1/stores/:store_id/discounts/:id
      def update
        @discount.update!(discount_params)
        render json: @discount
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # DELETE /api/v1/stores/:store_id/discounts/:id
      def destroy
        @discount.soft_delete!
        head :no_content
      end

      # POST /api/v1/stores/:store_id/discounts/validate
      # Public endpoint — validates a discount code for a given order total.
      def validate_code
        result = Checkout::ApplyDiscount.call(
          store:       Current.store,
          code:        params[:code],
          order_total: params[:order_total].to_d
        )

        if result.success?
          render json: {
            valid:           true,
            code:            params[:code].upcase,
            discount_type:   result.object[:discount].discount_type,
            value:           result.object[:discount].value.to_s,
            discount_amount: result.object[:amount].to_s
          }
        else
          render json: { valid: false, errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      def set_discount
        @discount = TenantScoped.with_bypass do
          Current.store.discounts.find(params[:id])
        end
      end

      def discount_params
        params.require(:discount).permit(
          :code, :discount_type, :value, :min_order_amount,
          :usage_limit, :starts_at, :ends_at, :active
        )
      end
    end
  end
end
