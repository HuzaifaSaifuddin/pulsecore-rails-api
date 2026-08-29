class Api::V1::AdmissionsController < Api::V1::BaseController
  before_action :require_current_facility!, only: [ :index, :create ]

  def index
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    admissions = Admission.visible_to(current_user)
      .where(facility: current_user.default_facility)
      .same_day_as(date)
      .includes(:patient, :doctor)

    render json: { admissions: AdmissionSerializer.render_collection(admissions) }
  end

  def create
    admission = current_user.default_facility.admissions.build(admission_params)
    stamp_notes_updated_by!(admission)

    if admission.save
      render json: { admission: AdmissionSerializer.new(admission).as_json }, status: :created
    else
      render json: { errors: admission.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    admission = Admission.visible_to(current_user).find(params[:id])
    admission.assign_attributes(admission_update_params)
    stamp_notes_updated_by!(admission)

    if admission.save
      render json: { admission: AdmissionSerializer.new(admission).as_json }
    else
      render json: { errors: admission.errors.full_messages }, status: :unprocessable_content
    end
  end

  def advance_status
    perform_transition(:advance_status)
  end

  def revert_status
    perform_transition(:revert_status)
  end

  def cancel
    perform_transition(:cancel)
  end

  def uncancel
    perform_transition(:uncancel)
  end

  private

  def perform_transition(action)
    admission = Admission.visible_to(current_user).find(params[:id])

    if admission.public_send(action)
      render json: { admission: AdmissionSerializer.new(admission).as_json }
    else
      fallback = "Unable to #{action.to_s.humanize.downcase}"
      render json: { errors: admission.errors.full_messages.presence || [ fallback ] },
        status: :unprocessable_content
    end
  end

  def stamp_notes_updated_by!(admission)
    return unless admission.notes_changed?

    admission.notes_updated_by = current_user
    admission.notes_updated_at = Time.current
  end

  def admission_params
    params.require(:admission).permit(:patient_id, :doctor_id, :admission_start, :admission_end, :notes)
  end

  def admission_update_params
    params.require(:admission).permit(:doctor_id, :admission_start, :admission_end, :notes)
  end
end
