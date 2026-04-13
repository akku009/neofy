class ApplicationService
  # Call pattern: Products::CreateProduct.call(store: ..., params: ...)
  def self.call(...)
    new(...).call
  end

  # Lightweight Result value object — avoids exceptions for expected business failures.
  ServiceResult = Struct.new(:success, :object, :errors, keyword_init: true) do
    def success? = success
    def failure? = !success
  end

  private

  def success(object = nil)
    ServiceResult.new(success: true, object: object, errors: [])
  end

  def failure(*errors)
    ServiceResult.new(success: false, object: nil, errors: errors.flatten)
  end
end
