module Api
  module V1
    class MembershipsController < ApplicationController
      before_action :require_store_context!
      before_action :set_membership, only: %i[show update destroy]

      # GET /api/v1/stores/:store_id/memberships
      def index
        members = TenantScoped.with_bypass do
          Current.store.memberships.includes(:user).active
        end
        render json: members.map { |m| membership_json(m) }
      end

      # POST /api/v1/stores/:store_id/memberships
      # Invite a user by email to join the store
      def create
        gate = Billing::CheckFeatureAccess.call(
          store:         Current.store,
          feature:       :max_staff,
          current_count: TenantScoped.with_bypass { Current.store.memberships.active.count }
        )
        return render json: { errors: gate.errors }, status: :payment_required if gate.failure?

        user = TenantScoped.with_bypass { User.find_by(email: params[:email]&.downcase&.strip) }
        return render json: { errors: ["User not found"] }, status: :not_found unless user

        existing = TenantScoped.with_bypass do
          Current.store.memberships.find_by(user_id: user.id)
        end
        return render json: { errors: ["User is already a member"] }, status: :conflict if existing

        membership = TenantScoped.with_bypass do
          Current.store.memberships.create!(
            user:   user,
            role:   params[:role] || "staff",
            status: "active"
          )
        end

        render json: membership_json(membership), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      # PATCH /api/v1/stores/:store_id/memberships/:id
      def update
        return render json: { error: "Cannot change owner role" }, status: :forbidden if @membership.role_owner?

        @membership.update!(role: params[:role])
        render json: membership_json(@membership)
      end

      # DELETE /api/v1/stores/:store_id/memberships/:id
      def destroy
        return render json: { error: "Cannot remove store owner" }, status: :forbidden if @membership.role_owner?

        @membership.destroy!
        head :no_content
      end

      private

      def set_membership
        @membership = TenantScoped.with_bypass do
          Current.store.memberships.find(params[:id])
        end
      end

      def membership_json(m)
        {
          id:           m.id,
          role:         m.role,
          status:       m.status,
          user_email:   m.user.email,
          user_name:    m.user.full_name,
          accepted_at:  m.accepted_at,
          created_at:   m.created_at
        }
      end
    end
  end
end
