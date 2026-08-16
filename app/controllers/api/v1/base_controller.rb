class Api::V1::BaseController < ApplicationController
  before_action :authenticate_user!

  private

  def require_org_admin!
    return if current_user.org_admin?

    render json: { error: "Forbidden" }, status: :forbidden
  end
end
