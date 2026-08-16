class Admission < ApplicationRecord
  NEXT_STATUS = {
    "scheduled" => "arrived",
    "arrived" => "admitted",
    "admitted" => "discharged"
  }.freeze

  PREVIOUS_STATUS = NEXT_STATUS.invert.freeze

  OCCUPYING_STATUSES = %w[arrived admitted].freeze
  ACTIVE_STATUSES = %w[scheduled arrived admitted].freeze

  belongs_to :patient
  belongs_to :facility
  belongs_to :doctor, class_name: "User", optional: true
  belongs_to :notes_updated_by, class_name: "User", optional: true

  enum :status, {
    scheduled: "scheduled",
    arrived: "arrived",
    admitted: "admitted",
    discharged: "discharged",
    cancelled: "cancelled"
  }

  validate :patient_and_facility_belong_to_same_organization
  validate :patient_and_doctor_belong_to_same_organization
  validate :patient_and_notes_updated_by_belong_to_same_organization
  validate :no_conflicting_scheduled_admission_same_day
  validate :no_conflicting_occupying_admission

  validates :status, :admission_start, presence: true
  validates :admission_end, comparison: { greater_than: :admission_start, message: "must be after admission start" }, allow_nil: true

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :occupied, -> { where(status: OCCUPYING_STATUSES) }
  scope :same_day_as, ->(time) { where(admission_start: time.all_day) }

  def advance_status
    next_status = NEXT_STATUS[status]

    return false if next_status.nil?
    return false if admission_start.to_date > Time.current.to_date

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

  def no_conflicting_scheduled_admission_same_day
    return if patient.nil? || admission_start.nil?
    return unless status == "scheduled"

    conflict_exists = patient.admissions.active.same_day_as(admission_start).where.not(id: id).exists?

    return unless conflict_exists

    errors.add(:admission_start, "conflicts with another admission the same day")
  end

  def no_conflicting_occupying_admission
    return if patient.nil?
    return unless status.in?(OCCUPYING_STATUSES)

    conflict_exists = patient.admissions.occupied.where.not(id: id).exists?

    return unless conflict_exists

    errors.add(:admission_start, "conflicts with another arrived or admitted admission -- discharge or cancel that one first.")
  end
end
