class AdmissionSerializer < ApplicationSerializer
  def initialize(admission)
    @admission = admission
  end

  def as_json(*)
    {
      id: admission.id,
      patient_id: admission.patient_id,
      facility_id: admission.facility_id,
      doctor_id: admission.doctor_id,
      status: admission.status,
      admission_start: admission.admission_start,
      admission_end: admission.admission_end,
      notes: admission.notes,
      notes_updated_by_id: admission.notes_updated_by_id,
      notes_updated_at: admission.notes_updated_at
    }
  end

  private

  attr_reader :admission
end
