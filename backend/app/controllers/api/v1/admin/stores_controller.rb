module Api
  module V1
    module Admin
      class StoresController < BaseController
        # GET /api/v1/admin/stores
        def index
          stores = TenantScoped.with_bypass do
            Store.includes(:user, :active_subscription)
                 .filter_by_status(params[:status])
                 .order(created_at: :desc)
                 .page(params[:page])
                 .per(params[:per_page] || 25)
          end

          render json: {
            stores: stores.map { |s| admin_store_json(s) },
            meta:   pagination_meta(stores)
          }
        end

        # GET /api/v1/admin/stores/:id
        def show
          store = TenantScoped.with_bypass { Store.find(params[:id]) }
          render json: admin_store_json(store, detailed: true)
        end

        # PATCH /api/v1/admin/stores/:id/suspend
        def suspend
          store = TenantScoped.with_bypass { Store.find(params[:id]) }
          store.update!(status: :suspended)
          render json: { id: store.id, status: store.status, message: "Store suspended" }
        end

        # PATCH /api/v1/admin/stores/:id/activate
        def activate
          store = TenantScoped.with_bypass { Store.find(params[:id]) }
          store.update!(status: :active)
          render json: { id: store.id, status: store.status, message: "Store activated" }
        end

        private

        def admin_store_json(store, detailed: false)
          base = {
            id:          store.id,
            name:        store.name,
            subdomain:   store.subdomain,
            plan:        store.plan,
            status:      store.status,
            owner_email: store.user&.email,
            created_at:  store.created_at
          }
          return base unless detailed

          sub = TenantScoped.with_bypass { store.active_subscription }
          base.merge(
            subscription: sub ? { plan: sub.plan.name, status: sub.status } : nil,
            products_count: TenantScoped.with_bypass { store.products.count },
            orders_count:   TenantScoped.with_bypass { store.orders.count }
          )
        end

        def pagination_meta(collection)
          { current_page: collection.current_page, total_pages: collection.total_pages,
            total_count: collection.total_count, per_page: collection.limit_value }
        end
      end
    end
  end
end
