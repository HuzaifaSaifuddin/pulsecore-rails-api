require 'rails_helper'

RSpec.describe Organization, type: :model do
  describe "validations" do
    it "is invalid without a name" do
      organization = described_class.new(name: nil)

      expect(organization).not_to be_valid
      expect(organization.errors[:name]).to include("can't be blank")
    end

    context "when the name is already taken" do
      before { described_class.create!(name: "Fortis") }

      it "is invalid" do
        organization = described_class.new(name: "Fortis")

        expect(organization).not_to be_valid
        expect(organization.errors[:name]).to include("has already been taken")
      end
    end
  end

  describe "associations" do
    it "has many facilities" do
      organization = described_class.create!(name: "Fortis")
      facility = Facility.create!(name: "Main Clinic", organization: organization)

      expect(organization.facilities).to contain_exactly(facility)
    end
  end
end
