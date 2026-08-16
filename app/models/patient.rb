class Patient < ApplicationRecord
  belongs_to :organization

  enum :gender, {
    male: "male",
    female: "female",
    other: "other"
  }

  before_validation :normalize_names

  validates :first_name, :last_name, :date_of_birth, :gender, :phone_number, presence: true

  validates :mrn, presence: true, uniqueness: { scope: :organization_id }

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence
  end

  private

  def normalize_names
    self.first_name = first_name.strip if first_name.present?
    self.last_name = last_name.strip if last_name.present?
  end
end
