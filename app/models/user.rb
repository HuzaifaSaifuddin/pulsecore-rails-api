class User < ApplicationRecord
  belongs_to :organization
  belongs_to :default_facility, class_name: "Facility", optional: true

  has_many :facility_memberships
  has_many :facilities, through: :facility_memberships

  enum :role, {
    org_admin: "org_admin",
    doctor: "doctor",
    receptionist: "receptionist"
  }

  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :role, presence: true

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence
  end
end
