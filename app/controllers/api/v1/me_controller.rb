class Api::V1::MeController < Api::V1::BaseController
  def show
    render json: session_payload
  end

  # Brief §5: a user with several accessible facilities picks their current one here (the SPA's
  # nav-bar facility switcher, and the "choose a facility" step after login). The target must
  # be one of the user's own accessible facilities -- `accessible_facilities.find_by` gives the
  # tenant + membership check in one, and a miss 422s rather than silently no-op'ing.
  def update
    facility = current_user.accessible_facilities.find_by(id: me_params[:default_facility_id])

    if facility
      current_user.update!(default_facility: facility)
      render json: session_payload
    else
      render json: { errors: [ "Default facility must be one of your accessible facilities" ] },
        status: :unprocessable_content
    end
  end

  private

  def session_payload
    {
      user: UserSerializer.new(current_user).as_json,
      current_facility: current_user.default_facility && FacilitySerializer.new(current_user.default_facility).as_json,
      accessible_facilities: FacilitySerializer.render_collection(current_user.accessible_facilities)
    }
  end

  def me_params
    params.require(:user).permit(:default_facility_id)
  end
end
