class AppointmentSerializer < ApplicationSerializer
  def initialize(appointment)
    @appointment = appointment
  end

  def as_json(*)
    {
      id: appointment.id,
      patient_id: appointment.patient_id,
      facility_id: appointment.facility_id,
      doctor_id: appointment.doctor_id,
      status: appointment.status,
      scheduled_start: appointment.scheduled_start,
      scheduled_end: appointment.scheduled_end,
      notes: appointment.notes,
      notes_updated_by_id: appointment.notes_updated_by_id,
      notes_updated_at: appointment.notes_updated_at
    }
  end

  private

  attr_reader :appointment
end
