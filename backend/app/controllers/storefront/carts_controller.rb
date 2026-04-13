module Storefront
  class CartsController < BaseController
    skip_before_action :load_active_theme!, only: %i[add update remove]

    # GET /cart
    def show
      render_storefront_template("cart", {
        cart:       cart_template_context,
        store:      @store.to_template_hash
      })
    end

    # POST /cart/items  { variant_id:, quantity: }
    def add
      variant = TenantScoped.with_bypass do
        Variant.where(id: params[:variant_id], store_id: @store.id).first
      end

      return render json: { error: "Variant not found" }, status: :not_found unless variant

      qty = [params[:quantity].to_i, 1].max
      current_cart.add_item!(variant, quantity: qty)

      render json: {
        cart:  cart_json,
        count: current_cart.reload.items_count
      }
    end

    # PATCH /cart/items/:variant_id  { quantity: }
    def update
      current_cart.update_item!(params[:variant_id], params[:quantity].to_i)
      render json: { cart: cart_json, count: current_cart.reload.items_count }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Item not in cart" }, status: :not_found
    end

    # DELETE /cart/items/:variant_id
    def remove
      current_cart.remove_item!(params[:variant_id])
      render json: { cart: cart_json, count: current_cart.reload.items_count }
    end

    private

    def cart_template_context
      {
        "items"       => cart_items_context,
        "total"       => current_cart.total_price.to_s,
        "items_count" => current_cart.items_count.to_s,
        "currency"    => @store.currency
      }
    end

    def cart_items_context
      current_cart.cart_items.includes(variant: :product).map do |item|
        {
          "variant_id"    => item.variant_id,
          "title"         => item.variant&.product&.title.to_s,
          "variant_title" => item.variant&.title.to_s,
          "price"         => item.price.to_s,
          "quantity"      => item.quantity.to_s,
          "line_total"    => item.line_total.to_s,
          "image_url"     => item.variant&.image_url.to_s,
          "handle"        => item.variant&.product&.handle.to_s
        }
      end
    end

    def cart_json
      {
        items:       cart_items_context,
        total:       current_cart.total_price.to_s,
        items_count: current_cart.items_count,
        currency:    @store.currency
      }
    end
  end
end
