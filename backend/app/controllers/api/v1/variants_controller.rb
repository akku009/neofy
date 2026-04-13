module Api
  module V1
    class VariantsController < ApplicationController
      before_action :require_store_context!
      before_action :set_product,  only: %i[index create]
      before_action :set_variant,  only: %i[show update destroy inventory]

      # GET /api/v1/stores/:store_id/products/:product_id/variants
      def index
        authorize Variant, :index?

        variants = @product.variants.order(:position)
        render json: variants, each_serializer: VariantSerializer
      end

      # GET /api/v1/variants/:id
      def show
        authorize @variant
        render json: @variant, serializer: VariantSerializer
      end

      # POST /api/v1/stores/:store_id/products/:product_id/variants
      def create
        authorize Variant, :create?

        variant = @product.variants.build(
          variant_params.merge(store_id: Current.store.id)
        )

        if variant.save
          render json: variant, serializer: VariantSerializer, status: :created
        else
          render json: { errors: variant.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/variants/:id
      def update
        authorize @variant

        if @variant.update(variant_params)
          render json: @variant, serializer: VariantSerializer
        else
          render json: { errors: @variant.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/variants/:id
      def destroy
        authorize @variant

        @variant.soft_delete!
        head :no_content
      end

      # PATCH /api/v1/variants/:id/inventory
      def inventory
        authorize @variant, :inventory?

        result = Inventory::UpdateInventory.call(
          variant:    @variant,
          quantity:   inventory_params[:quantity],
          adjustment: inventory_params[:adjustment] || "set"
        )

        if result.success?
          render json: result.object, serializer: VariantSerializer
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      private

      def set_product
        @product = Current.store.products.find(params[:product_id])
      end

      # For shallow routes (/variants/:id), there is no :store_id or :product_id
      # in the URL. We load the variant bypassing the default scope, then enforce
      # tenant ownership explicitly — this is the single cross-tenant security gate.
      def set_variant
        @variant = TenantScoped.with_bypass { Variant.find(params[:id]) }

        # If no store context yet (shallow route without subdomain), resolve
        # from the variant itself — but only if the user owns that store.
        if Current.store.nil?
          store = TenantScoped.with_bypass do
            current_user.stores.find_by(id: @variant.store_id)
          end
          return render json: { error: "Not found" }, status: :not_found if store.nil?

          Current.store = store
        end

        # Enforce tenant isolation — variant must belong to the current store.
        unless @variant.store_id == Current.store.id
          render json: { error: "Not found" }, status: :not_found
        end
      end

      def variant_params
        params.require(:variant).permit(
          :title, :sku, :price, :compare_at_price, :cost_per_item,
          :inventory_quantity, :inventory_policy,
          :weight, :weight_unit,
          :option1, :option2, :option3,
          :barcode, :image_url, :position,
          :taxable, :requires_shipping
        )
      end

      def inventory_params
        params.require(:inventory).permit(:quantity, :adjustment)
      end
    end
  end
end
