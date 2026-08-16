class Api::V1::BaseController < ApplicationController
  before_action :authenticate_user!

  private

  def require_org_admin!
    return if current_user.org_admin?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  # Brief §5: facility-scoped screens (Appointments, Admissions) operate against a single
  # "current facility" -- no per-action facility picker. §8 suggests a distinguishable
  # response (409) the SPA's router intercepts to redirect to a "choose facility" step.
  def require_current_facility!
    return if current_user.default_facility_id.present?

    render json: { error: "No current facility selected" }, status: :conflict
  end
end
