module Storefront
  class CheckoutsController < BaseController
    # GET /checkout
    def show
      return redirect_to "/cart" if current_cart.cart_items.empty?

      rates = available_shipping_rates

      render_storefront_template("checkout", {
        cart:            cart_context,
        shipping_rates:  rates,
        store:           @store.to_template_hash
      })
    end

    # POST /checkout  — creates order + returns payment intent client_secret
    def create
      return render json: { error: "Cart is empty" }, status: :unprocessable_entity if current_cart.cart_items.empty?

      # Build checkout params from cart
      checkout_params = current_cart.to_checkout_params.merge(
        customer:         { email: params[:email], first_name: params[:first_name], last_name: params[:last_name] },
        shipping_address: shipping_params,
        billing_address:  billing_params || shipping_params,
        note:             params[:note],
        discount_code:    params[:discount_code]
      )

      result = Checkout::CreateOrder.call(
        store:        @store,
        params:       checkout_params,
        current_user: nil
      )

      unless result.success?
        return render json: { errors: result.errors }, status: :unprocessable_entity
      end

      order = result.object
      current_cart.update!(status: "converted", completed_at: Time.current)
      cookies.delete(:cart_token)

      # Create Stripe payment intent immediately
      intent_result = Payments::CreatePaymentIntent.call(order: order, store: @store)

      render json: {
        order_id:      order.id,
        order_number:  order.order_number,
        total_price:   order.total_price.to_s,
        currency:      order.currency,
        client_secret: intent_result.success? ? intent_result.object[:client_secret] : nil
      }
    end

    # GET /checkout/success?order_id=
    def success
      @order = TenantScoped.with_bypass { @store.orders.find_by(id: params[:order_id]) }
      return redirect_to "/" unless @order

      render_storefront_template("order_confirmation", {
        order:    order_context(@order),
        store:    @store.to_template_hash
      })
    end

    private

    def available_shipping_rates
      country = params[:country].to_s.upcase.presence || "US"

      TenantScoped.with_bypass do
        # Load all active zones with their active rates in 2 queries (no N+1).
        zones = @store.shipping_zones
                      .where(active: true)
                      .includes(:shipping_rates)

        zones
          .select { |z| z.covers_country?(country) }
          .flat_map { |z| z.shipping_rates.select(&:active?) }
          .sort_by(&:price)
          .map { |r| { "id" => r.id, "name" => r.name, "price" => r.price.to_s,
                        "delivery_estimate" => r.delivery_estimate } }
      end
    end

    def cart_context
      {
        "items"       => current_cart.cart_items.includes(variant: :product).map { |i|
          { "title" => i.variant&.product&.title.to_s, "variant_title" => i.variant&.title.to_s,
            "price" => i.price.to_s, "quantity" => i.quantity.to_s, "line_total" => i.line_total.to_s }
        },
        "total"    => current_cart.total_price.to_s,
        "currency" => @store.currency
      }
    end

    def order_context(order)
      {
        "order_number"     => order.order_number,
        "total_price"      => order.total_price.to_s,
        "currency"         => order.currency,
        "financial_status" => order.financial_status,
        "email"            => order.email.to_s
      }
    end

    def shipping_params
      {
        first_name: sanitize_input(params[:first_name], 100),
        last_name:  sanitize_input(params[:last_name],  100),
        address1:   sanitize_input(params[:address1],   255),
        address2:   sanitize_input(params[:address2],   255),
        city:       sanitize_input(params[:city],       100),
        province:   sanitize_input(params[:province],   100),
        country:    sanitize_input(params[:country],     10),
        zip:        sanitize_input(params[:zip],         20),
        phone:      sanitize_input(params[:phone],       30)
      }.compact
    end

    def sanitize_input(val, max_len)
      return nil if val.blank?
      val.to_s.delete("\u0000").strip.truncate(max_len, omission: "")
    end

    def billing_params
      return nil unless params[:billing_same] == "false"
      {
        first_name: params[:billing_first_name],
        last_name:  params[:billing_last_name],
        address1:   params[:billing_address1],
        city:       params[:billing_city],
        country:    params[:billing_country],
        zip:        params[:billing_zip]
      }.compact
    end
  end
end
