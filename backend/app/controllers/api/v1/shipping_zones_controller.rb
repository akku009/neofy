module Api
  module V1
    class ShippingZonesController < ApplicationController
      before_action :require_store_context!
      before_action :set_zone, only: %i[show update destroy]

      # GET /api/v1/stores/:store_id/shipping_zones
      def index
        zones = TenantScoped.with_bypass do
          Current.store.shipping_zones.includes(:shipping_rates).active
        end
        render json: zones.map { |z| zone_json(z) }
      end

      # POST /api/v1/stores/:store_id/shipping_zones
      def create
        zone = TenantScoped.with_bypass do
          Current.store.shipping_zones.create!(zone_params)
        end
        render json: zone_json(zone), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # PATCH /api/v1/stores/:store_id/shipping_zones/:id
      def update
        @zone.update!(zone_params)
        render json: zone_json(@zone)
      end

      # DELETE /api/v1/stores/:store_id/shipping_zones/:id
      def destroy
        @zone.destroy!
        head :no_content
      end

      # POST /api/v1/stores/:store_id/shipping_zones/:id/rates
      def add_rate
        rate = @zone.shipping_rates.create!(rate_params)
        render json: rate_json(rate), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # GET /api/v1/stores/:store_id/shipping_zones/calculate
      # Returns applicable shipping rates for a given country + order total.
      def calculate
        country     = params[:country].to_s.upcase
        order_total = params[:order_total].to_d

        zones = TenantScoped.with_bypass do
          Current.store.shipping_zones.includes(:shipping_rates).active.select { |z| z.covers_country?(country) }
        end

        rates = zones.flat_map { |z| z.shipping_rates.where(active: true) }
                     .map { |r| rate_json(r) }
                     .uniq { |r| r[:name] }
                     .sort_by { |r| r[:price].to_f }

        render json: { shipping_rates: rates }
      end

      private

      def set_zone
        @zone = TenantScoped.with_bypass { Current.store.shipping_zones.find(params[:id]) }
      end

      def zone_params
        params.require(:shipping_zone).permit(:name, :active, :position, countries: [])
      end

      def rate_params
        params.require(:shipping_rate).permit(
          :name, :price, :min_order_amount, :min_weight, :max_weight,
          :estimated_days_min, :estimated_days_max, :active
        )
      end

      def zone_json(z)
        { id: z.id, name: z.name, countries: z.countries, active: z.active,
          rates: z.shipping_rates.map { |r| rate_json(r) } }
      end

      def rate_json(r)
        { id: r.id, name: r.name, price: r.price.to_s,
          delivery_estimate: r.delivery_estimate, active: r.active }
      end
    end
  end
end
