module Api
  module V1
    class ThemesController < ApplicationController
      before_action :require_store_context!
      before_action :set_theme, only: %i[show update activate]

      # GET /api/v1/stores/:store_id/themes
      def index
        themes = TenantScoped.with_bypass do
          Theme.where(store_id: Current.store.id).includes(:templates)
        end
        render json: themes, each_serializer: ThemeSerializer
      end

      # GET /api/v1/stores/:store_id/themes/:id
      def show
        render json: @theme, serializer: ThemeSerializer
      end

      # POST /api/v1/stores/:store_id/themes
      def create
        theme = TenantScoped.with_bypass do
          Theme.create!(store_id: Current.store.id, name: theme_params[:name], active: false)
        end
        render json: theme, serializer: ThemeSerializer, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # PATCH /api/v1/stores/:store_id/themes/:id/activate
      def activate
        @theme.activate!
        render json: @theme.reload, serializer: ThemeSerializer
      rescue => e
        render json: { errors: [e.message] }, status: :unprocessable_entity
      end

      private

      def set_theme
        @theme = TenantScoped.with_bypass do
          Theme.find_by!(id: params[:id], store_id: Current.store.id)
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Theme not found" }, status: :not_found
      end

      def theme_params
        params.require(:theme).permit(:name)
      end
    end
  end
end
