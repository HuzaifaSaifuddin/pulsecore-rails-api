class Api::V1::AppointmentsController < Api::V1::BaseController
  before_action :require_current_facility!, only: [ :index, :create ]

  def index
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    appointments = Appointment.visible_to(current_user)
      .where(facility: current_user.default_facility)
      .same_day_as(date)
      .includes(:patient, :doctor)

    render json: { appointments: AppointmentSerializer.render_collection(appointments) }
  end

  def create
    # Facility is always the Current Facility, never client-selectable (brief §7's two-step
    # booking flow: "facility always fixed to the Current Facility -- never form-selectable").
    appointment = current_user.default_facility.appointments.build(appointment_params)
    stamp_notes_updated_by!(appointment)

    if appointment.save
      render json: { appointment: AppointmentSerializer.new(appointment).as_json }, status: :created
    else
      render json: { errors: appointment.errors.full_messages }, status: :unprocessable_content
    end
  end

  def update
    appointment = Appointment.visible_to(current_user).find(params[:id])
    appointment.assign_attributes(appointment_update_params)
    stamp_notes_updated_by!(appointment)

    if appointment.save
      render json: { appointment: AppointmentSerializer.new(appointment).as_json }
    else
      render json: { errors: appointment.errors.full_messages }, status: :unprocessable_content
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

  # advance_status/revert_status/cancel/uncancel all return false in two different situations
  # that look identical from here: a plain business-rule no-op (e.g. already terminal, or the
  # future-day guard on advance_status) that never touches .errors at all, and a real validation
  # failure from the underlying update (e.g. a same-day conflict) that does. errors.full_messages
  # is empty in the first case, so it falls back to a generic message -- both cases render the
  # same 422 shape as every other validation failure in this API, rather than inventing a third
  # status code just for "this transition isn't allowed right now."
  def perform_transition(action)
    appointment = Appointment.visible_to(current_user).find(params[:id])

    if appointment.public_send(action)
      render json: { appointment: AppointmentSerializer.new(appointment).as_json }
    else
      fallback = "Unable to #{action.to_s.humanize.downcase}"
      render json: { errors: appointment.errors.full_messages.presence || [ fallback ] },
        status: :unprocessable_content
    end
  end

  def stamp_notes_updated_by!(appointment)
    return unless appointment.notes_changed?

    appointment.notes_updated_by = current_user
    appointment.notes_updated_at = Time.current
  end

  def appointment_params
    params.require(:appointment).permit(:patient_id, :doctor_id, :scheduled_start, :scheduled_end, :notes)
  end

  # patient_id/facility_id are not editable after creation -- status changes go through the
  # dedicated advance_status/revert_status/cancel/uncancel actions below, not a plain update.
  def appointment_update_params
    params.require(:appointment).permit(:doctor_id, :scheduled_start, :scheduled_end, :notes)
  end
end
