module Products
  class DestroyProduct < ApplicationService
    def initialize(product:)
      @product = product
    end

    def call
      ActiveRecord::Base.transaction do
        # Soft-delete all variants first, then the product.
        # Uses with_deleted scope to also catch already-soft-deleted variants
        # in case they need to be kept as audit records.
        @product.variants.each(&:soft_delete!)
        @product.soft_delete!
      end

      success(@product)
    rescue => e
      failure(e.message)
    end
  end
end
