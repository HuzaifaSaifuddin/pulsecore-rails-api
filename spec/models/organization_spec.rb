require "rails_helper"

RSpec.describe Organization, type: :model do
  describe "validations" do
    it "is invalid without a name" do
      organization = build(:organization, name: nil)

      expect(organization).not_to be_valid
      expect(organization.errors[:name]).to include("can't be blank")
    end

    context "when the name is already taken" do
      before { create(:organization, name: "Fortis") }

      it "is invalid" do
        organization = build(:organization, name: "Fortis")

        expect(organization).not_to be_valid
        expect(organization.errors[:name]).to include("has already been taken")
      end
    end
  end

  describe "associations" do
    it "has many facilities" do
      organization = create(:organization)
      facility = create(:facility, organization: organization)

      expect(organization.facilities).to contain_exactly(facility)
    end
  end
end
