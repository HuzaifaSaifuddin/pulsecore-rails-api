class Users::SessionsController < Devise::SessionsController
  private

  def respond_with(resource, _opts = {})
    render json: { user: UserSerializer.new(resource).as_json }, status: :ok
  end

  def respond_to_on_destroy(non_navigational_status: :no_content)
    head non_navigational_status
  end
end
