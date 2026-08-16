require "rails_helper"

RSpec.describe Appointment, type: :model do
  let(:organization) { create(:organization) }
  let(:patient) { create(:patient, organization: organization) }

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

    describe "scheduled_end" do
      context "when scheduled_end is before scheduled_start" do
        it "is invalid" do
          appointment = build(:appointment,
            scheduled_start: Time.zone.local(2026, 3, 5, 10, 0),
            scheduled_end: Time.zone.local(2026, 3, 5, 9, 0))

          expect(appointment).not_to be_valid
          expect(appointment.errors[:scheduled_end]).to include("must be after scheduled start")
        end
      end

      context "when scheduled_end equals scheduled_start" do
        it "is invalid" do
          time = Time.zone.local(2026, 3, 5, 10, 0)
          appointment = build(:appointment, scheduled_start: time, scheduled_end: time)

          expect(appointment).not_to be_valid
          expect(appointment.errors[:scheduled_end]).to include("must be after scheduled start")
        end
      end

      context "when scheduled_end is blank" do
        it "is valid" do
          appointment = build(:appointment, scheduled_end: nil)

          expect(appointment).to be_valid
        end
      end
    end

    describe "same-day active appointment conflict" do
      context "when the patient already has another active appointment the same day" do
        before do
          create(:appointment, organization: organization, patient: patient,
            scheduled_start: Time.zone.local(2026, 3, 5, 9, 0), status: "scheduled")
        end

        it "is invalid" do
          appointment = build(:appointment, organization: organization, patient: patient,
            scheduled_start: Time.zone.local(2026, 3, 5, 15, 0), status: "scheduled")

          expect(appointment).not_to be_valid
          expect(appointment.errors[:scheduled_start]).to include("conflicts with another active appointment")
        end
      end

      context "when the existing same-day appointment is completed" do
        before do
          create(:appointment, organization: organization, patient: patient,
            scheduled_start: Time.zone.local(2026, 3, 5, 9, 0), status: "completed")
        end

        it "is valid" do
          appointment = build(:appointment, organization: organization, patient: patient,
            scheduled_start: Time.zone.local(2026, 3, 5, 15, 0), status: "scheduled")

          expect(appointment).to be_valid
        end
      end

      context "when the conflicting appointment is on a different day" do
        before do
          create(:appointment, organization: organization, patient: patient,
            scheduled_start: Time.zone.local(2026, 3, 4, 9, 0), status: "scheduled")
        end

        it "is valid" do
          appointment = build(:appointment, organization: organization, patient: patient,
            scheduled_start: Time.zone.local(2026, 3, 5, 9, 0), status: "scheduled")

          expect(appointment).to be_valid
        end
      end

      context "when the appointment being validated is itself not active" do
        before do
          create(:appointment, organization: organization, patient: patient,
            scheduled_start: Time.zone.local(2026, 3, 5, 9, 0), status: "scheduled")
        end

        it "is valid" do
          appointment = build(:appointment, organization: organization, patient: patient,
            scheduled_start: Time.zone.local(2026, 3, 5, 15, 0), status: "cancelled")

          expect(appointment).to be_valid
        end
      end

      context "revalidating an already-persisted active appointment" do
        it "does not conflict with itself" do
          appointment = create(:appointment, organization: organization, patient: patient,
            scheduled_start: Time.zone.local(2026, 3, 5, 9, 0), status: "scheduled")

          expect(appointment).to be_valid
        end
      end
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

  describe "#advance_status" do
    context "when the scheduled day is in the future" do
      it "does not advance the status" do
        appointment = create(:appointment, scheduled_start: 1.day.from_now)

        expect(appointment.advance_status).to be_falsy
        expect(appointment).to be_scheduled
      end
    end

    context "when the scheduled day is today" do
      it "advances from scheduled to arrived" do
        appointment = create(:appointment)

        expect(appointment.advance_status).to be_truthy
        expect(appointment).to be_arrived
      end
    end

    context "when the appointment is already completed" do
      it "does not change the status" do
        appointment = create(:appointment, status: "completed")

        expect(appointment.advance_status).to be_falsy
        expect(appointment).to be_completed
      end
    end

    context "when the appointment is cancelled" do
      it "does not change the status" do
        appointment = create(:appointment, status: "cancelled")

        expect(appointment.advance_status).to be_falsy
        expect(appointment).to be_cancelled
      end
    end

    context "when scheduled_start is 'today' in IST but 'yesterday' in UTC" do
      it "advances the status" do
        # 1am IST on March 5 is 7:30pm UTC on March 4 — a UTC-based comparison
        # would wrongly see this scheduled_start as still in the future.
        travel_to(Time.zone.local(2026, 3, 5, 1, 0, 0)) do
          appointment = create(:appointment, scheduled_start: Time.current)

          expect(appointment.advance_status).to be_truthy
          expect(appointment).to be_arrived
        end
      end
    end
  end

  describe "#revert_status" do
    context "when the appointment is scheduled" do
      it "does not change the status" do
        appointment = create(:appointment, status: "scheduled")

        expect(appointment.revert_status).to be_falsy
        expect(appointment).to be_scheduled
      end
    end

    context "when the appointment is cancelled" do
      it "does not change the status" do
        appointment = create(:appointment, status: "cancelled")

        expect(appointment.revert_status).to be_falsy
        expect(appointment).to be_cancelled
      end
    end

    context "when the appointment is in progress" do
      it "reverts the status" do
        appointment = create(:appointment, status: "in_progress")

        expect(appointment.revert_status).to be_truthy
        expect(appointment).to be_arrived
      end
    end

    context "when the appointment is completed and no conflicting appointment exists" do
      it "reverts the status" do
        appointment = create(:appointment, status: "completed")

        expect(appointment.revert_status).to be_truthy
        expect(appointment).to be_in_progress
      end
    end

    context "when the appointment is already completed and an active appointment exists" do
      it "does not change the status" do
        appointment = create(:appointment, organization: organization, patient: patient,
          scheduled_start: Time.zone.local(2026, 3, 5, 9, 0), status: "completed")
        create(:appointment, organization: organization, patient: patient,
          scheduled_start: Time.zone.local(2026, 3, 5, 15, 0), status: "scheduled")

        expect(appointment.revert_status).to be_falsy
        expect(appointment.errors[:scheduled_start]).to include("conflicts with another active appointment")
        expect(appointment.reload).to be_completed
      end
    end
  end

  describe "#cancel" do
    context "when the appointment is not scheduled" do
      it "does not change the status" do
        appointment = create(:appointment, status: "arrived")

        expect(appointment.cancel).to be_falsy
        expect(appointment).to be_arrived
      end
    end

    context "when the appointment is scheduled" do
      it "cancels" do
        appointment = create(:appointment, status: "scheduled")

        expect(appointment.cancel).to be_truthy
        expect(appointment).to be_cancelled
      end
    end
  end

  describe "#uncancel" do
    context "when the appointment is not cancelled" do
      it "does not change the status" do
        appointment = create(:appointment, status: "arrived")

        expect(appointment.uncancel).to be_falsy
        expect(appointment).to be_arrived
      end
    end

    context "when the appointment is cancelled" do
      it "uncancels" do
        appointment = create(:appointment, status: "cancelled")

        expect(appointment.uncancel).to be_truthy
        expect(appointment).to be_scheduled
      end
    end

    context "when the appointment is cancelled and an active appointment exists" do
      it "does not change the status" do
        appointment = create(:appointment, organization: organization, patient: patient,
          scheduled_start: Time.zone.local(2026, 3, 5, 9, 0), status: "cancelled")
        create(:appointment, organization: organization, patient: patient,
          scheduled_start: Time.zone.local(2026, 3, 5, 15, 0), status: "scheduled")

        expect(appointment.uncancel).to be_falsy
        expect(appointment.errors[:scheduled_start]).to include("conflicts with another active appointment")
        expect(appointment.reload).to be_cancelled
      end
    end
  end
end
