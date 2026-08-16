class FacilitySerializer < ApplicationSerializer
  def initialize(facility)
    @facility = facility
  end

  def as_json(*)
    {
      id: facility.id,
      name: facility.name,
      organization_id: facility.organization_id
    }
  end

  private

  attr_reader :facility
end
