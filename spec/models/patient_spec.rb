require "rails_helper"

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

    it "is invalid if mrn is blanked out on an existing patient" do
      patient = create(:patient)

      expect(patient.update(mrn: nil)).to be false
      expect(patient.errors[:mrn]).to include("can't be blank")
    end

    context "when the mrn is already taken in the same organization" do
      let(:organization) { create(:organization) }

      before { create(:patient, organization: organization, mrn: "P-000001") }

      it "is invalid" do
        patient = build(:patient, organization: organization, mrn: "P-000001")

        expect(patient).not_to be_valid
        expect(patient.errors[:mrn]).to include("has already been taken")
      end
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

  describe "mrn generation" do
    it "generates P-000001 for the first patient in an organization" do
      patient = create(:patient, mrn: nil)

      expect(patient.mrn).to eq("P-000001")
    end

    it "generates a sequential mrn for the next patient in the same organization" do
      organization = create(:organization)
      create(:patient, organization: organization, mrn: nil)

      second_patient = create(:patient, organization: organization, mrn: nil)

      expect(second_patient.mrn).to eq("P-000002")
    end

    it "scopes the mrn sequence per organization" do
      first_organization = create(:organization)
      second_organization = create(:organization)
      create(:patient, organization: first_organization, mrn: nil)

      patient_in_second_org = create(:patient, organization: second_organization, mrn: nil)

      expect(patient_in_second_org.mrn).to eq("P-000001")
    end

    it "does not overwrite an explicitly provided mrn" do
      patient = create(:patient, mrn: "P-000042")

      expect(patient.mrn).to eq("P-000042")
    end

    it "locks the organization row before computing the next mrn" do
      organization = create(:organization)

      expect(organization).to receive(:lock!).and_call_original

      create(:patient, organization: organization, mrn: nil)
    end
  end
end
