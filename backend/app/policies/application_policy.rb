class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "Must be logged in" unless user

    @user   = user
    @record = record
  end

  def index?   = false
  def show?    = false
  def create?  = false
  def update?  = false
  def destroy? = false

  class Scope
    def initialize(user, scope)
      @user  = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "#{self.class}#resolve is not implemented"
    end

    private

    attr_reader :user, :scope
  end

  private

  # ── Tenant ownership check ───────────────────────────────────────────────────
  # Returns true if the currently authenticated user owns the active store.
  def store_owner?
    Current.store.present? && Current.store.user_id == user.id
  end

  def platform_admin?
    user.role_admin?
  end
end
