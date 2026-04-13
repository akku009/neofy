module Products
  class CreateProduct < ApplicationService
    def initialize(store:, params:)
      @store  = store
      @params = params.to_h.with_indifferent_access
    end

    def call
      product = @store.products.build(product_attrs)

      ActiveRecord::Base.transaction do
        product.save!
        build_variants!(product) if variants_data.any?
      end

      success(product.reload)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    rescue ArgumentError => e
      failure(e.message)
    end

    private

    def product_attrs
      @params.except("variants", "variant")
    end

    def variants_data
      Array(@params["variants"] || @params["variant"])
    end

    def build_variants!(product)
      variants_data.each_with_index do |vattrs, idx|
        product.variants.create!(
          vattrs.merge(
            store_id: @store.id,
            position: vattrs[:position] || idx + 1
          )
        )
      end
    end
  end
end
