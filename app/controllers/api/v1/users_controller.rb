class Api::V1::UsersController < Api::V1::BaseController
  before_action :require_org_admin!, only: [ :create, :update ]

  def index
    users = User.visible_to(current_user).includes(:facility_memberships)
    render json: { users: UserSerializer.render_collection(users) }
  end

  def create
    attrs = user_params
    user = current_user.organization.users.build(attrs.except(:facility_ids))
    save_with_memberships!(user, attrs)

    render json: { user: UserSerializer.new(user).as_json }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
  end

  def update
    attrs = user_update_params
    user = User.visible_to(current_user).find(params[:id])
    user.assign_attributes(attrs.except(:facility_ids))
    save_with_memberships!(user, attrs)

    render json: { user: UserSerializer.new(user).as_json }
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
  end

  private

  # Persists the user and, only when `facility_ids` was in the payload, syncs their explicit
  # FacilityMemberships to it (see User#assign_facility_memberships). One transaction, so a
  # later validation failure rolls the membership changes back too. On create the user has to
  # be saved before membership rows can reference it, hence the second save! -- it persists
  # the default_facility_id that assign_facility_memberships derives.
  def save_with_memberships!(user, attrs)
    ActiveRecord::Base.transaction do
      user.save!
      if attrs.key?(:facility_ids)
        user.assign_facility_memberships(attrs[:facility_ids])
        user.save!
      end
    end
  end

  # org_admin supplies the new staff member's initial password directly -- brief doesn't
  # specify an invite/reset-token flow for staff creation, and building one would mean
  # depending on the password-reset flow. Revisit if an invite-style flow is wanted instead.
  # `facility_ids` sets which facilities the user is a member of (multi-select); see
  # User#assign_facility_memberships for the default_facility derivation.
  def user_params
    params.require(:user).permit(:email, :password, :first_name, :last_name, :role, facility_ids: [])
  end

  # Narrower than create: email is the login identifier (correcting it is its own concern,
  # not routine staff management), password goes through the reset flow, organization_id is
  # never client-settable.
  def user_update_params
    params.require(:user).permit(:first_name, :last_name, :role, facility_ids: [])
  end
end
