require 'rails_helper'

RSpec.describe Patient, type: :model do
  describe "validations" do
    it "is invalid without a first_name" do
      patient = build(:patient, first_name: nil)

      expect(patient).not_to be_valid
      expect(patient.errors[:first_name]).to include("can't be blank")
    end

    it "is invalid without a last_name" do
      patient = build(:patient, last_name: nil)

      expect(patient).not_to be_valid
      expect(patient.errors[:last_name]).to include("can't be blank")
    end

    it "is invalid without a date_of_birth" do
      patient = build(:patient, date_of_birth: nil)

      expect(patient).not_to be_valid
      expect(patient.errors[:date_of_birth]).to include("can't be blank")
    end

    it "is invalid without a gender" do
      patient = build(:patient, gender: nil)

      expect(patient).not_to be_valid
      expect(patient.errors[:gender]).to include("can't be blank")
    end

    it "is invalid without a phone_number" do
      patient = build(:patient, phone_number: nil)

      expect(patient).not_to be_valid
      expect(patient.errors[:phone_number]).to include("can't be blank")
    end

    it "is invalid without an organization" do
      patient = build(:patient, organization: nil)

      expect(patient).not_to be_valid
      expect(patient.errors[:organization]).to include("must exist")
    end

    it "rejects a gender outside the allowed set" do
      patient = build(:patient)

      expect { patient.gender = "invalid" }.to raise_error(ArgumentError)
    end
  end

  describe "associations" do
    it "belongs to an organization" do
      organization = create(:organization)
      patient = create(:patient, organization: organization)

      expect(patient.organization).to eq organization
    end
  end

  describe "#full_name" do
    it "joins first and last name" do
      patient = build(:patient, first_name: "Jane", last_name: "Doe")

      expect(patient.full_name).to eq "Jane Doe"
    end
  end

  describe "name normalization" do
    it "strips leading and trailing whitespace from first and last names" do
      patient = build(:patient, first_name: "  Jane  ", last_name: "  Doe  ")

      patient.valid?

      expect(patient.first_name).to eq("Jane")
      expect(patient.last_name).to eq("Doe")
    end
  end
end
