module Api
  module V1
    module Admin
      # Base controller for platform-level admin endpoints.
      # Requires the authenticated user to have the :admin role.
      class BaseController < ApplicationController
        before_action :require_platform_admin!

        private

        def require_platform_admin!
          return if current_user&.role_admin?

          render json: { error: "Platform admin access required" }, status: :forbidden
        end
      end
    end
  end
end
