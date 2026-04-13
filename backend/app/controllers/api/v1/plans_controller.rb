module Api
  module V1
    class PlansController < ApplicationController
      skip_before_action :authenticate_user!, only: %i[index show]
      skip_before_action :resolve_tenant_from_subdomain, only: %i[index show]

      # GET /api/v1/plans
      def index
        render json: Plan.active, each_serializer: PlanSerializer
      end

      # GET /api/v1/plans/:id
      def show
        plan = Plan.find(params[:id])
        render json: plan, serializer: PlanSerializer
      end
    end
  end
end
