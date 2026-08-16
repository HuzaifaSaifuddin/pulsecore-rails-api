class Appointment < ApplicationRecord
  belongs_to :patient
  belongs_to :facility
  belongs_to :doctor, class_name: "User", optional: true
  belongs_to :notes_updated_by, class_name: "User", optional: true

  enum :status, {
    scheduled: "scheduled",
    arrived: "arrived",
    in_progress: "in_progress",
    completed: "completed",
    cancelled: "cancelled"
  }

  validate :patient_and_facility_belong_to_same_organization
  validate :patient_and_doctor_belong_to_same_organization
  validate :patient_and_notes_updated_by_belong_to_same_organization

  validates :status, :scheduled_start, presence: true

  private

  def patient_and_facility_belong_to_same_organization
    validate_same_organization(:facility)
  end

  def patient_and_doctor_belong_to_same_organization
    validate_same_organization(:doctor)
  end

  def patient_and_notes_updated_by_belong_to_same_organization
    validate_same_organization(:notes_updated_by)
  end

  def validate_same_organization(attribute)
    record = public_send(attribute)

    return if patient.nil? || record.nil?
    return if patient.organization_id == record.organization_id

    errors.add(attribute, "must belong to the patient's organization")
  end
end
