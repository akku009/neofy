class OrderPolicy < ApplicationPolicy
  def index?          = store_owner? || platform_admin?
  def show?           = store_owner? || platform_admin?
  def create?         = store_owner?
  def cancel?         = store_owner?
  def fulfill?        = store_owner?
  def payment_intent? = store_owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.role_admin?
        scope.for_platform.all
      else
        scope.where(store_id: user.store_ids)
      end
    end
  end
end
