module Api
  module V1
    module Admin
      class AnalyticsController < BaseController
        # GET /api/v1/admin/analytics
        def platform_metrics
          since = Time.current - (params[:days]&.to_i || 30).days

          total_revenue = TenantScoped.with_bypass do
            Payment.where(status: :succeeded, created_at: since..)
                   .sum(:amount)
                   .to_s
          end

          total_orders = TenantScoped.with_bypass do
            Order.where(financial_status: :paid, created_at: since..).count
          end

          active_stores = TenantScoped.with_bypass { Store.status_active.count }
          total_stores  = TenantScoped.with_bypass { Store.count }

          active_subs = TenantScoped.with_bypass do
            Subscription.where(status: %i[trialing active]).count
          end

          mrr = TenantScoped.with_bypass do
            Subscription.joins(:plan)
                        .where(status: :active, billing_interval: "monthly")
                        .sum("plans.price_monthly")
                        .to_s
          end

          render json: {
            period_days:      params[:days]&.to_i || 30,
            total_revenue:    total_revenue,
            total_orders:     total_orders,
            total_stores:     total_stores,
            active_stores:    active_stores,
            active_subscriptions: active_subs,
            monthly_recurring_revenue: mrr
          }
        end
      end
    end
  end
end
