class Users::SessionsController < Devise::SessionsController
  private

  def respond_with(resource, _opts = {})
    render json: { user: user_json(resource) }, status: :ok
  end

  def respond_to_on_destroy(non_navigational_status: :no_content)
    head non_navigational_status
  end

  def user_json(user)
    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      role: user.role,
      organization_id: user.organization_id,
      default_facility_id: user.default_facility_id
    }
  end
end
