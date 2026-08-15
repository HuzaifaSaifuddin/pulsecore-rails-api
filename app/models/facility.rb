class Facility < ApplicationRecord
  belongs_to :organization

  has_many :facility_memberships
  has_many :users, through: :facility_memberships

  validates :name, presence: true, uniqueness: { scope: :organization_id }
end
