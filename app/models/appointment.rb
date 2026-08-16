class Appointment < ApplicationRecord
  NEXT_STATUS = {
    "scheduled" => "arrived",
    "arrived" => "in_progress",
    "in_progress" => "completed"
  }.freeze

  PREVIOUS_STATUS = NEXT_STATUS.invert.freeze

  ACTIVE_STATUSES = %w[scheduled arrived in_progress].freeze

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
  validate :no_conflicting_active_appointment

  validates :status, :scheduled_start, presence: true
  validates :scheduled_end, comparison: { greater_than: :scheduled_start, message: "must be after scheduled start" }, allow_nil: true

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :same_day_as, ->(time) { where(scheduled_start: time.all_day) }
  scope :visible_to, ->(user) { where(facility_id: user.accessible_facilities) }

  def advance_status
    next_status = NEXT_STATUS[status]

    return false if next_status.nil?
    return false if scheduled_start.to_date > Time.current.to_date

    update(status: next_status)
  end

  def revert_status
    previous_status = PREVIOUS_STATUS[status]
    return false if previous_status.nil?

    update(status: previous_status)
  end

  def cancel
    return false if status != "scheduled"

    update(status: "cancelled")
  end

  def uncancel
    return false if status != "cancelled"

    update(status: "scheduled")
  end

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

  def no_conflicting_active_appointment
    return if patient.nil? || scheduled_start.nil?
    return unless status.in?(ACTIVE_STATUSES)

    conflict_exists = patient.appointments.active.same_day_as(scheduled_start).where.not(id: id).exists?

    return unless conflict_exists

    errors.add(:scheduled_start, "conflicts with another active appointment")
  end
end
