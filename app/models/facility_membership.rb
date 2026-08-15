class FacilityMembership < ApplicationRecord
  belongs_to :user
  belongs_to :facility

  validates :facility_id, uniqueness: { scope: :user_id }

  after_commit :invalidate_accessible_facilities_cache, on: [ :create, :destroy ]

  private

  def invalidate_accessible_facilities_cache
    Rails.cache.delete(User.accessible_facilities_cache_key(user_id))
  end
end
