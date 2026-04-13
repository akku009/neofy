module Storefront
  class CustomerSessionsController < BaseController
    skip_before_action :load_active_theme!, only: %i[create destroy]

    # GET /account/login
    def new
      redirect_to "/account" if logged_in?
      render_storefront_template("customer_login", {})
    end

    # POST /account/login
    def create
      email    = params[:email].to_s.downcase.strip
      password = params[:password].to_s

      customer = TenantScoped.with_bypass do
        Customer.find_by(store_id: @store.id, email: email)
      end

      if customer&.has_account? && customer.authenticate(password)
        token = customer.generate_remember_token!
        customer.update!(last_sign_in_at: Time.current)
        cookies.signed[:customer_token] = {
          value:    token,
          expires:  30.days,
          httponly: true,
          secure:   Rails.env.production?
        }
        # Sanitize return_to: only allow relative paths (starting with /) to prevent open redirect.
        safe_return = params[:return_to].to_s.presence
        safe_return = nil unless safe_return&.start_with?("/") && !safe_return.start_with?("//")
        redirect_to safe_return || "/account"
      else
        render_storefront_template("customer_login", {
          error: "Invalid email or password"
        })
      end
    end

    # DELETE /account/logout
    def destroy
      current_customer&.clear_remember_token!
      cookies.delete(:customer_token)
      redirect_to "/"
    end
  end
end
