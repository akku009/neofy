module Analytics
  class StoreDashboard < ApplicationService
    PERIODS = {
      "7d"  => 7.days,
      "30d" => 30.days,
      "90d" => 90.days,
      "1y"  => 1.year
    }.freeze

    def initialize(store:, period: "30d")
      @store = store
      @since = Time.current - (PERIODS[period] || 30.days)
    end

    def call
      success({
        period_start: @since.iso8601,
        period_end:   Time.current.iso8601,
        revenue:      revenue_metrics,
        orders:       order_metrics,
        products:     product_metrics,
        customers:    customer_metrics,
        top_products: top_products
      })
    end

    private

    def scoped_orders
      TenantScoped.with_bypass { @store.orders.where(created_at: @since..) }
    end

    def revenue_metrics
      paid_orders = TenantScoped.with_bypass { @store.orders.paid.where(created_at: @since..) }
      {
        total:   paid_orders.sum(:total_price).to_s,
        count:   paid_orders.count,
        average: paid_orders.average(:total_price)&.round(2).to_s
      }
    end

    def order_metrics
      orders = scoped_orders
      {
        total:       orders.count,
        paid:        orders.where(financial_status: :paid).count,
        pending:     orders.where(financial_status: :pending).count,
        cancelled:   orders.where.not(cancelled_at: nil).count
      }
    end

    def product_metrics
      TenantScoped.with_bypass do
        {
          total:    @store.products.count,
          active:   @store.products.status_active.count,
          in_stock: @store.variants.where("inventory_quantity > 0").count
        }
      end
    end

    def customer_metrics
      TenantScoped.with_bypass do
        {
          total: @store.customers.count,
          new:   @store.customers.where(created_at: @since..).count
        }
      end
    end

    def top_products
      TenantScoped.with_bypass do
        @store.order_items
              .where(created_at: @since..)
              .joins(:product)
              .select("products.title, products.handle, SUM(order_items.quantity) AS total_sold, SUM(order_items.price * order_items.quantity) AS total_revenue")
              .group("order_items.product_id, products.title, products.handle")
              .order("total_sold DESC")
              .limit(5)
              .map do |item|
                {
                  title:         item.title,
                  handle:        item.handle,
                  total_sold:    item.total_sold.to_i,
                  total_revenue: item.total_revenue.to_s
                }
              end
      end
    end
  end
end
