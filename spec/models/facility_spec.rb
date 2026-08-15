require 'rails_helper'

RSpec.describe Facility, type: :model do
  describe "validations" do
    it "is invalid without a name" do
      facility = described_class.new(name: nil)

      expect(facility).not_to be_valid
      expect(facility.errors[:name]).to include("can't be blank")
    end

    it "is invalid without an organization" do
      facility = described_class.new(name: 'Main Branch', organization: nil)

      expect(facility).not_to be_valid
      expect(facility.errors[:organization]).to include("must exist")
    end

    context "when the name is already taken" do
      let(:organization) { Organization.create!(name: "Fortis") }

      before do
        described_class.create!(name: "Fortis", organization: organization)
      end

      it "is invalid" do
        facility = described_class.new(name: "Fortis", organization: organization)

        expect(facility).not_to be_valid
        expect(facility.errors[:name]).to include("has already been taken")
      end
    end

    context "when the name is already taken by another organization" do
      let(:organization) { Organization.create!(name: "Fortis") }
      let(:other_organization) { Organization.create!(name: "Apollo") }

      before do
        described_class.create!(name: "Main Clinic", organization: organization)
      end

      it "is valid" do
        facility = described_class.new(name: "Main Clinic", organization: other_organization)

        expect(facility).to be_valid
      end
    end
  end

  describe "associations" do
    it "belongs to an organization" do
      organization = Organization.create!(name: "Fortis")
      facility = described_class.create!(name: "Main Clinic", organization: organization)

      expect(facility.organization).to eq organization
    end
  end
end
