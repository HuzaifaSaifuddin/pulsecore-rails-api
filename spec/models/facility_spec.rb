require 'rails_helper'

RSpec.describe Facility, type: :model do
  describe "validations" do
    it "is invalid without a name" do
      facility = build(:facility, name: nil)

      expect(facility).not_to be_valid
      expect(facility.errors[:name]).to include("can't be blank")
    end

    it "is invalid without an organization" do
      facility = build(:facility, organization: nil)

      expect(facility).not_to be_valid
      expect(facility.errors[:organization]).to include("must exist")
    end

    context "when the name is already taken" do
      let(:organization) { create(:organization) }

      before { create(:facility, name: "Main Clinic", organization: organization) }

      it "is invalid" do
        facility = build(:facility, name: "Main Clinic", organization: organization)

        expect(facility).not_to be_valid
        expect(facility.errors[:name]).to include("has already been taken")
      end
    end

    context "when the name is already taken by another organization" do
      let(:organization) { create(:organization) }
      let(:other_organization) { create(:organization) }

      before { create(:facility, name: "Main Clinic", organization: organization) }

      it "is valid" do
        facility = build(:facility, name: "Main Clinic", organization: other_organization)

        expect(facility).to be_valid
      end
    end
  end

  describe "associations" do
    it "belongs to an organization" do
      organization = create(:organization)
      facility = create(:facility, organization: organization)

      expect(facility.organization).to eq organization
    end
  end
end
