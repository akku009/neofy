class CustomerPolicy < ApplicationPolicy
  def index?   = store_owner? || platform_admin?
  def show?    = store_owner? || platform_admin?
  def create?  = store_owner?
  def update?  = store_owner?
  def destroy? = store_owner?

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
