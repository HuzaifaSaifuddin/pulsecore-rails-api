class Api::V1::MeController < Api::V1::BaseController
  def show
    render json: {
      user: UserSerializer.new(current_user).as_json,
      current_facility: current_user.default_facility && FacilitySerializer.new(current_user.default_facility).as_json,
      accessible_facilities: FacilitySerializer.render_collection(current_user.accessible_facilities)
    }
  end
end
