class Api::V1::UsersController < Api::V1::BaseController
  before_action :require_org_admin!, only: [ :create ]

  def index
    users = User.visible_to(current_user)
    render json: { users: UserSerializer.render_collection(users) }
  end

  def create
    user = current_user.organization.users.build(user_params)

    if user.save
      render json: { user: UserSerializer.new(user).as_json }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  # org_admin supplies the new staff member's initial password directly -- brief
  # doesn't specify an invite/reset-token flow for staff creation, and building one
  # would mean depending on the password-reset flow (checkpoint 5 remainder, not
  # built yet). Revisit once that exists if an invite-style flow is wanted instead.
  def user_params
    params.require(:user).permit(:email, :password, :first_name, :last_name, :role)
  end
end
