class PatientSerializer < ApplicationSerializer
  def initialize(patient)
    @patient = patient
  end

  def as_json(*)
    {
      id: patient.id,
      mrn: patient.mrn,
      first_name: patient.first_name,
      last_name: patient.last_name,
      date_of_birth: patient.date_of_birth,
      gender: patient.gender,
      phone_number: patient.phone_number,
      email: patient.email,
      organization_id: patient.organization_id
    }
  end

  private

  attr_reader :patient
end
