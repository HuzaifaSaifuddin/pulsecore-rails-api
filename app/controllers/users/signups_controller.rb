# Deliberately not Api::V1::BaseController -- this is the one unauthenticated endpoint in the
# whole API, the only way an Organization ever gets created (brief §6). Grouped with
# Users::SessionsController since both are unauthenticated, User-identity-related, Devise-
# adjacent concerns, but mounted under /api/v1/signup in routes.rb -- the URL isn't Devise-routed
# so nothing forces it under /users/... the way sessions are, and every other endpoint in this
# API lives under /api/v1.
class Users::SignupsController < ApplicationController
  def create
    organization = nil
    facility = nil
    user = nil

    ActiveRecord::Base.transaction do
      organization = Organization.create!(organization_params)
      facility = organization.facilities.create!(name: organization.name)
      user = organization.users.create!(
        admin_params.merge(role: "org_admin", default_facility: facility)
      )
    end

    sign_in(user)
    render json: {
      user: UserSerializer.new(user).as_json,
      organization: OrganizationSerializer.new(organization).as_json,
      facility: FacilitySerializer.new(facility).as_json
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_content
  end

  private

  def organization_params
    params.require(:organization).permit(:name, :email, :phone_number)
  end

  def admin_params
    params.require(:user).permit(:email, :password, :first_name, :last_name)
  end
end
