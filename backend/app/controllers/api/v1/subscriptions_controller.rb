module Api
  module V1
    class SubscriptionsController < ApplicationController
      before_action :require_store_context!
      before_action :set_subscription, only: %i[show cancel]

      # GET /api/v1/stores/:store_id/subscription
      def show
        subscription = Current.store.active_subscription
        if subscription
          render json: subscription, serializer: SubscriptionSerializer
        else
          render json: { subscription: nil, on_free_plan: true }
        end
      end

      # POST /api/v1/stores/:store_id/subscription
      # Body: { subscription: { plan_id: "uuid", interval: "monthly"|"yearly" } }
      def create
        plan = Plan.find_by(id: subscription_params[:plan_id])
        return render json: { errors: ["Plan not found"] }, status: :not_found unless plan

        result = Billing::CreateSubscription.call(
          store:    Current.store,
          plan:     plan,
          interval: subscription_params[:interval] || "monthly"
        )

        if result.success?
          render json: result.object, serializer: SubscriptionSerializer, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/stores/:store_id/subscription
      def cancel
        result = Billing::CancelSubscription.call(
          subscription:         @subscription,
          cancel_at_period_end: params[:immediate].blank?
        )

        if result.success?
          render json: result.object, serializer: SubscriptionSerializer
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/stores/:store_id/subscription/change_plan
      def change_plan
        new_plan = Plan.find_by(id: params[:plan_id])
        return render json: { errors: ["Plan not found"] }, status: :not_found unless new_plan

        sub = Current.store.active_subscription
        return render json: { errors: ["No active subscription"] }, status: :not_found unless sub

        result = Billing::ChangePlan.call(
          subscription: sub,
          new_plan:     new_plan,
          interval:     params[:interval]
        )

        if result.success?
          render json: result.object, serializer: SubscriptionSerializer
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/plans  (platform-level, no store required)
      def plans
        render json: Plan.active, each_serializer: PlanSerializer
      end

      private

      def set_subscription
        @subscription = Current.store.active_subscription
        render json: { errors: ["No active subscription"] }, status: :not_found unless @subscription
      end

      def subscription_params
        params.require(:subscription).permit(:plan_id, :interval)
      end
    end
  end
end
