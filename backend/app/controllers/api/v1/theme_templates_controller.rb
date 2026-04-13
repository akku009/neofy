module Api
  module V1
    class ThemeTemplatesController < ApplicationController
      before_action :require_store_context!
      before_action :set_theme
      before_action :set_template, only: %i[show update]

      # GET /api/v1/stores/:store_id/themes/:theme_id/templates
      def index
        render json: @theme.templates, each_serializer: ThemeTemplateSerializer
      end

      # GET /api/v1/stores/:store_id/themes/:theme_id/templates/:id
      def show
        render json: @template, serializer: ThemeTemplateSerializer
      end

      # PUT /api/v1/stores/:store_id/themes/:theme_id/templates/:id
      def update
        if @template.update(template_params)
          render json: @template, serializer: ThemeTemplateSerializer
        else
          render json: { errors: @template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/stores/:store_id/themes/:theme_id/templates
      def create
        template = @theme.templates.build(template_params)
        if template.save
          render json: template, serializer: ThemeTemplateSerializer, status: :created
        else
          render json: { errors: template.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_theme
        @theme = TenantScoped.with_bypass do
          Theme.find_by!(id: params[:theme_id], store_id: Current.store.id)
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Theme not found" }, status: :not_found
      end

      def set_template
        @template = @theme.templates.find(params[:id])
      end

      def template_params
        params.require(:theme_template).permit(:name, :content)
      end
    end
  end
end
