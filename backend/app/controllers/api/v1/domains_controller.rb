module Api
  module V1
    class DomainsController < ApplicationController
      before_action :require_store_context!
      before_action :set_domain, only: %i[show verify set_primary destroy]

      # GET /api/v1/stores/:store_id/domains
      def index
        authorize Domain, :index?

        domains = TenantScoped.with_bypass do
          Domain.where(store_id: Current.store.id).order(primary: :desc, created_at: :asc)
        end

        render json: domains, each_serializer: DomainSerializer
      end

      # GET /api/v1/stores/:store_id/domains/:id
      def show
        authorize @domain
        render json: @domain, serializer: DomainSerializer
      end

      # POST /api/v1/stores/:store_id/domains
      # Body: { domain: { domain: "mystore.com" } }
      def create
        authorize Domain, :create?

        result = Domains::AddDomain.call(
          store:      Current.store,
          domain_str: domain_params[:domain]
        )

        if result.success?
          render json: result.object, serializer: DomainSerializer, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/stores/:store_id/domains/:id/verify
      # Triggers a DNS TXT record lookup to verify domain ownership.
      def verify
        authorize @domain, :verify?

        result = Domains::VerifyDomain.call(domain: @domain)

        if result.success?
          render json: result.object, serializer: DomainSerializer
        else
          render json: {
            errors:               result.errors,
            verification_record: {
              type:  "TXT",
              name:  @domain.txt_record_name,
              value: @domain.txt_record_value
            }
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/stores/:store_id/domains/:id/set_primary
      def set_primary
        authorize @domain, :set_primary?

        result = Domains::SetPrimaryDomain.call(
          domain: @domain,
          store:  Current.store
        )

        if result.success?
          render json: result.object, serializer: DomainSerializer
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/stores/:store_id/domains/:id
      def destroy
        authorize @domain

        @domain.destroy!
        head :no_content
      end

      private

      def set_domain
        @domain = TenantScoped.with_bypass do
          Domain.find_by!(id: params[:id], store_id: Current.store.id)
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Domain not found" }, status: :not_found
      end

      def domain_params
        params.require(:domain).permit(:domain)
      end
    end
  end
end
