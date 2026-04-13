module Api
  module V1
    class ProductsController < ApplicationController
      before_action :require_store_context!
      before_action :set_product, only: %i[show update destroy publish unpublish]

      # GET /api/v1/stores/:store_id/products
      def index
        authorize Product, :index?

        products = Current.store.products
                         .includes(:variants)
                         .filter_by_status(params[:status])
                         .search(params[:q])
                         .order(created_at: :desc)
                         .page(params[:page])
                         .per(params[:per_page] || 20)

        render json: {
          products: serialize_collection(products, ProductSerializer),
          meta:     pagination_meta(products)
        }
      end

      # GET /api/v1/stores/:store_id/products/:id
      def show
        authorize @product
        render json: @product, serializer: ProductSerializer
      end

      # POST /api/v1/stores/:store_id/products
      def create
        authorize Product, :create?

        gate = Billing::CheckFeatureAccess.call(
          store:         Current.store,
          feature:       :max_products,
          current_count: TenantScoped.with_bypass { Current.store.products.count }
        )
        return render json: { errors: gate.errors }, status: :payment_required if gate.failure?

        result = Products::CreateProduct.call(
          store:  Current.store,
          params: product_params
        )

        if result.success?
          render json: result.object, serializer: ProductSerializer, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # PUT/PATCH /api/v1/stores/:store_id/products/:id
      def update
        authorize @product

        result = Products::UpdateProduct.call(
          product: @product,
          params:  product_params
        )

        if result.success?
          render json: result.object, serializer: ProductSerializer
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/stores/:store_id/products/:id
      def destroy
        authorize @product

        result = Products::DestroyProduct.call(product: @product)

        if result.success?
          head :no_content
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/stores/:store_id/products/:id/publish
      def publish
        authorize @product, :update?
        @product.publish!
        render json: @product, serializer: ProductSerializer
      end

      # PATCH /api/v1/stores/:store_id/products/:id/unpublish
      def unpublish
        authorize @product, :update?
        @product.unpublish!
        render json: @product, serializer: ProductSerializer
      end

      private

      def set_product
        @product = Current.store.products.find(params[:id])
      end

      def product_params
        params.require(:product).permit(
          :title, :description, :handle, :product_type, :vendor,
          :tags, :status, :published_at,
          variants: %i[
            id title sku price compare_at_price cost_per_item
            inventory_quantity inventory_policy
            weight weight_unit
            option1 option2 option3
            barcode image_url position taxable requires_shipping
          ]
        )
      end

      # ── Helpers ──────────────────────────────────────────────────────────────
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
