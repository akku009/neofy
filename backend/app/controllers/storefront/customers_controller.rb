module Storefront
  class CustomersController < BaseController
    before_action :require_customer_login!, only: %i[show orders order]

    # GET /account
    def show
      recent_orders = TenantScoped.with_bypass do
        current_customer.orders.order(created_at: :desc).limit(5)
      end

      render_storefront_template("customer_account", {
        customer:      customer_context,
        recent_orders: orders_context(recent_orders)
      })
    end

    # GET /account/register
    def new
      redirect_to "/account" if logged_in?
      render_storefront_template("customer_register", {})
    end

    # POST /account/register
    def create
      email = params[:email].to_s.downcase.strip

      customer = TenantScoped.with_bypass do
        Customer.find_or_initialize_by(store_id: @store.id, email: email)
      end

      if customer.persisted? && customer.has_account?
        return render_storefront_template("customer_register", {
          error: "An account with this email already exists."
        })
      end

      customer.assign_attributes(
        first_name: params[:first_name],
        last_name:  params[:last_name],
        password:   params[:password]
      )

      if customer.save
        token = customer.generate_remember_token!
        cookies.signed[:customer_token] = { value: token, expires: 30.days, httponly: true }
        redirect_to "/account"
      else
        render_storefront_template("customer_register", {
          error: customer.errors.full_messages.join(", ")
        })
      end
    end

    # GET /account/orders
    def orders
      orders = TenantScoped.with_bypass do
        current_customer.orders.includes(:order_items).order(created_at: :desc)
                        .page(params[:page]).per(10)
      end

      render_storefront_template("customer_orders", {
        customer: customer_context,
        orders:   orders_context(orders)
      })
    end

    # GET /account/orders/:id
    def order
      @order = TenantScoped.with_bypass do
        current_customer.orders.includes(:order_items).find_by!(id: params[:id])
      end

      render_storefront_template("customer_order_detail", {
        customer: customer_context,
        order:    order_detail_context(@order)
      })
    rescue ActiveRecord::RecordNotFound
      render_storefront_error("Order not found", :not_found)
    end

    private

    def customer_context
      {
        "id"         => current_customer.id,
        "email"      => current_customer.email,
        "first_name" => current_customer.first_name.to_s,
        "last_name"  => current_customer.last_name.to_s,
        "full_name"  => current_customer.full_name
      }
    end

    def orders_context(orders)
      orders.map do |o|
        {
          "id"               => o.id,
          "order_number"     => o.order_number,
          "total_price"      => o.total_price.to_s,
          "currency"         => o.currency,
          "financial_status" => o.financial_status,
          "items_count"      => o.items_count.to_s,
          "created_at"       => o.created_at.strftime("%B %d, %Y")
        }
      end
    end

    def order_detail_context(o)
      # Build items once — order.order_items already eager-loaded via controller
      items = o.order_items.map do |i|
        {
          "title"          => i.title,
          "variant_title"  => i.variant_title.to_s,
          "quantity"       => i.quantity.to_s,
          "price"          => i.price.to_s,
          "line_total"     => i.line_total.to_s
        }
      end

      {
        "order_number"     => o.order_number,
        "total_price"      => o.total_price.to_s,
        "currency"         => o.currency,
        "financial_status" => o.financial_status,
        "created_at"       => o.created_at.strftime("%B %d, %Y"),
        "items"            => items
      }
    end
  end
end
