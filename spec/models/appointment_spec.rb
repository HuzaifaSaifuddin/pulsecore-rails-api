require 'rails_helper'

RSpec.describe Appointment, type: :model do
  describe "validations" do
    it "is invalid without a patient" do
      appointment = build(:appointment, patient: nil)

      expect(appointment).not_to be_valid
      expect(appointment.errors[:patient]).to include("must exist")
    end

    it "is invalid without a facility" do
      appointment = build(:appointment, facility: nil)

      expect(appointment).not_to be_valid
      expect(appointment.errors[:facility]).to include("must exist")
    end

    it "is invalid without a status" do
      appointment = build(:appointment, status: nil)

      expect(appointment).not_to be_valid
      expect(appointment.errors[:status]).to include("can't be blank")
    end

    it "is invalid without a scheduled_start" do
      appointment = build(:appointment, scheduled_start: nil)

      expect(appointment).not_to be_valid
      expect(appointment.errors[:scheduled_start]).to include("can't be blank")
    end

    describe "organization consistency" do
      context "when the patient and facility belong to different organizations" do
        it "is invalid" do
          facility = build(:facility)
          appointment = build(:appointment, facility: facility)

          expect(appointment).not_to be_valid
          expect(appointment.errors[:facility]).to include("must belong to the patient's organization")
        end
      end

      context "when the patient and doctor belong to different organizations" do
        it "is invalid" do
          doctor = build(:user)
          appointment = build(:appointment, doctor: doctor)

          expect(appointment).not_to be_valid
          expect(appointment.errors[:doctor]).to include("must belong to the patient's organization")
        end
      end

      context "when the patient and notes_updated_by belong to different organizations" do
        it "is invalid" do
          notes_updated_by = build(:user)
          appointment = build(:appointment, notes_updated_by: notes_updated_by)

          expect(appointment).not_to be_valid
          expect(appointment.errors[:notes_updated_by]).to include("must belong to the patient's organization")
        end
      end
    end
  end

  describe "status" do
    it "defaults to scheduled" do
      appointment = create(:appointment)

      expect(appointment.status).to eq("scheduled")
    end

    it "rejects an invalid status" do
      appointment = build(:appointment)

      expect { appointment.status = "invalid" }.to raise_error(ArgumentError)
    end
  end
end
