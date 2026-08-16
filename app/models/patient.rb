class Patient < ApplicationRecord
  belongs_to :organization

  has_many :appointments
  has_many :admissions

  enum :gender, {
    male: "male",
    female: "female",
    other: "other"
  }

  before_validation :normalize_names
  before_create :generate_mrn, if: -> { mrn.blank? }

  validates :first_name, :last_name, :date_of_birth, :gender, :phone_number, presence: true

  validates :mrn, presence: true, on: :update
  validates :mrn, uniqueness: { scope: :organization_id }, allow_nil: true

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence
  end

  private

  def normalize_names
    self.first_name = first_name.strip if first_name.present?
    self.last_name = last_name.strip if last_name.present?
  end

  def generate_mrn
    organization.lock!
    last_mrn = organization.patients.maximum(:mrn)
    next_number = last_mrn ? last_mrn[/\d+/].to_i + 1 : 1
    self.mrn = format("P-%06d", next_number)
  end
end
