module Products
  class UpdateProduct < ApplicationService
    def initialize(product:, params:)
      @product = product
      @params  = params.to_h.with_indifferent_access
    end

    def call
      ActiveRecord::Base.transaction do
        @product.update!(product_attrs)
        sync_variants! if @params.key?("variants")
      end

      success(@product.reload)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    rescue ActiveRecord::RecordNotFound => e
      failure(e.message)
    end

    private

    def product_attrs
      @params.except("variants")
    end

    def sync_variants!
      incoming = Array(@params["variants"])

      incoming.each do |vdata|
        vdata = vdata.with_indifferent_access

        if vdata[:id].present?
          # Update existing variant — must belong to this product
          variant = @product.variants.find(vdata[:id])
          variant.update!(vdata.except(:id))
        else
          # Create new variant
          @product.variants.create!(
            vdata.merge(store_id: @product.store_id)
          )
        end
      end
    end
  end
end
