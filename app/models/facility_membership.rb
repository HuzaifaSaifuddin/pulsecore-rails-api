class FacilityMembership < ApplicationRecord
  belongs_to :user
  belongs_to :facility

  validates :facility_id, uniqueness: { scope: :user_id }
end
