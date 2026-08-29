class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :recoverable, :validatable

  belongs_to :organization
  belongs_to :default_facility, class_name: "Facility", optional: true

  has_many :facility_memberships
  has_many :facilities, through: :facility_memberships

  enum :role, {
    org_admin: "org_admin",
    doctor: "doctor",
    receptionist: "receptionist"
  }

  before_validation :normalize_names

  validates :email, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :role, presence: true

  scope :visible_to, ->(user) { where(organization_id: user.organization_id) }

  after_commit :invalidate_accessible_facilities_cache, on: :update, if: :saved_change_to_role?

  def self.accessible_facilities_cache_key(user_id)
    "accessible_facilities:#{user_id}"
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence
  end

  def accessible_facilities
    facility_ids = Rails.cache.fetch(self.class.accessible_facilities_cache_key(id), expires_in: 1.hour) do
      if org_admin?
        organization.facilities.pluck(:id)
      else
        facility_memberships.pluck(:facility_id)
      end
    end
    Facility.where(id: facility_ids)
  end

  # Replaces this user's explicit FacilityMemberships with exactly `facility_ids`, scoped to
  # the user's own organization -- ids from another org are silently ignored, same as every
  # other tenant-owned attribute in this API. Each add/remove goes through an individual
  # create!/destroy! so FacilityMembership's after_commit accessible_facilities cache
  # invalidation fires; a bulk delete_all would skip it.
  #
  # Also (re)derives default_facility: the sole assigned facility when exactly one, kept as-is
  # when it's still among several assigned, otherwise cleared -- a user with multiple
  # accessible facilities picks their current one on login or via PATCH /api/v1/me (brief §5).
  #
  # Does not save the user (the default_facility_id change); the caller does, inside a
  # transaction that also wraps the membership writes.
  def assign_facility_memberships(facility_ids)
    desired = organization.facilities.where(id: facility_ids).ids.to_set
    existing = facility_memberships.to_a

    existing.each { |membership| membership.destroy! unless desired.include?(membership.facility_id) }
    (desired - existing.map(&:facility_id)).each { |fid| facility_memberships.create!(facility_id: fid) }

    self.default_facility_id =
      if desired.one?
        desired.first
      elsif desired.include?(default_facility_id)
        default_facility_id
      end

    association(:facility_memberships).reset
  end

  private

  def normalize_names
    self.first_name = first_name.strip if first_name.present?
    self.last_name = last_name.strip if last_name.present?
  end

  def invalidate_accessible_facilities_cache
    Rails.cache.delete(self.class.accessible_facilities_cache_key(id))
  end
end
