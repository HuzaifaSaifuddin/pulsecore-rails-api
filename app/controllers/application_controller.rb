class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "Not found" }, status: :not_found
  end

  # Rails' enum macro raises ArgumentError for an unrecognized value (e.g. role:
  # "superadmin") rather than surfacing it as a normal validation error -- without
  # this, a bad enum value from a client would 500 instead of cleanly 422ing. Applies
  # to every enum-backed column accepted from params (User#role, Patient#gender,
  # Appointment/Admission#status later), not just this one controller.
  rescue_from ArgumentError do |exception|
    render json: { errors: [ exception.message ] }, status: :unprocessable_content
  end
end
