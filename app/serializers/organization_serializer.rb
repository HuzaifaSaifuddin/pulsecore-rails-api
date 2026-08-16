class OrganizationSerializer < ApplicationSerializer
  def initialize(organization)
    @organization = organization
  end

  def as_json(*)
    {
      id: organization.id,
      name: organization.name,
      email: organization.email,
      phone_number: organization.phone_number
    }
  end

  private

  attr_reader :organization
end
