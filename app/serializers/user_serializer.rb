class UserSerializer < ApplicationSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      role: user.role,
      organization_id: user.organization_id,
      default_facility_id: user.default_facility_id,
      facility_ids: user.facility_memberships.map(&:facility_id).sort
    }
  end

  private

  attr_reader :user
end
