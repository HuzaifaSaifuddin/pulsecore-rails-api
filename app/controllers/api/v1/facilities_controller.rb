class Api::V1::FacilitiesController < Api::V1::BaseController
  before_action :require_org_admin!, only: [ :create, :update ]

  def index
    facilities = Facility.visible_to(current_user)
    render json: { facilities: FacilitySerializer.render_collection(facilities) }
  end

  def create
    facility = current_user.organization.facilities.build(facility_params)

    if facility.save
      render json: { facility: FacilitySerializer.new(facility).as_json }, status: :created
    else
      render json: { errors: facility.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    facility = Facility.visible_to(current_user).find(params[:id])

    if facility.update(facility_params)
      render json: { facility: FacilitySerializer.new(facility).as_json }
    else
      render json: { errors: facility.errors.full_messages }, status: :unprocessable_content
    end
  end

  private

  def facility_params
    params.require(:facility).permit(:name)
  end
end
