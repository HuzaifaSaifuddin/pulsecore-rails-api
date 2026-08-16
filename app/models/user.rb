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

  private

  def normalize_names
    self.first_name = first_name.strip if first_name.present?
    self.last_name = last_name.strip if last_name.present?
  end

  def invalidate_accessible_facilities_cache
    Rails.cache.delete(self.class.accessible_facilities_cache_key(id))
  end
end
