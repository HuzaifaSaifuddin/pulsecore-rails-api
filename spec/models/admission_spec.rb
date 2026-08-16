require "rails_helper"

RSpec.describe Admission, type: :model do
  let(:organization) { create(:organization) }
  let(:patient) { create(:patient, organization: organization) }

  describe "validations" do
    it "is invalid without a patient" do
      admission = build(:admission, patient: nil)

      expect(admission).not_to be_valid
      expect(admission.errors[:patient]).to include("must exist")
    end

    it "is invalid without a facility" do
      admission = build(:admission, facility: nil)

      expect(admission).not_to be_valid
      expect(admission.errors[:facility]).to include("must exist")
    end

    it "is invalid without a status" do
      admission = build(:admission, status: nil)

      expect(admission).not_to be_valid
      expect(admission.errors[:status]).to include("can't be blank")
    end

    it "is invalid without a admission_start" do
      admission = build(:admission, admission_start: nil)

      expect(admission).not_to be_valid
      expect(admission.errors[:admission_start]).to include("can't be blank")
    end

    describe "admission_end" do
      context "when admission_end is before admission_start" do
        it "is invalid" do
          admission = build(:admission,
            admission_start: Time.zone.local(2026, 3, 5, 10, 0),
            admission_end: Time.zone.local(2026, 3, 5, 9, 0))

          expect(admission).not_to be_valid
          expect(admission.errors[:admission_end]).to include("must be after admission start")
        end
      end

      context "when admission_end equals admission_start" do
        it "is invalid" do
          time = Time.zone.local(2026, 3, 5, 10, 0)
          admission = build(:admission, admission_start: time, admission_end: time)

          expect(admission).not_to be_valid
          expect(admission.errors[:admission_end]).to include("must be after admission start")
        end
      end

      context "when admission_end is blank" do
        it "is valid" do
          admission = build(:admission, admission_end: nil)

          expect(admission).to be_valid
        end
      end
    end

    describe "same-day scheduled admission conflict" do
      context "when the patient already has another scheduled admission the same day" do
        before do
          create(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 5, 9, 0), status: "scheduled")
        end

        it "is invalid" do
          admission = build(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 5, 15, 0), status: "scheduled")

          expect(admission).not_to be_valid
          expect(admission.errors[:admission_start]).to include("conflicts with another admission the same day")
        end
      end

      context "when the patient already has an arrived admission the same day" do
        before do
          create(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 5, 9, 0), status: "arrived")
        end

        it "is invalid" do
          admission = build(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 5, 15, 0), status: "scheduled")

          expect(admission).not_to be_valid
          expect(admission.errors[:admission_start]).to include("conflicts with another admission the same day")
        end
      end

      context "when the existing same-day admission is discharged" do
        before do
          create(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 5, 9, 0), status: "discharged")
        end

        it "is valid" do
          admission = build(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 5, 15, 0), status: "scheduled")

          expect(admission).to be_valid
        end
      end

      context "when the conflicting admission is on a different day" do
        before do
          create(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 4, 9, 0), status: "scheduled")
        end

        it "is valid" do
          admission = build(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 5, 9, 0), status: "scheduled")

          expect(admission).to be_valid
        end
      end

      context "when the admission being validated is itself not scheduled" do
        before do
          create(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 5, 9, 0), status: "scheduled")
        end

        it "is valid" do
          admission = build(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 5, 15, 0), status: "cancelled")

          expect(admission).to be_valid
        end
      end

      context "revalidating an already-persisted scheduled admission" do
        it "does not conflict with itself" do
          admission = create(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 5, 9, 0), status: "scheduled")

          expect(admission).to be_valid
        end
      end
    end

    describe "occupying admission conflict" do
      context "when the patient already has an arrived admission, on any day" do
        before do
          create(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 1, 9, 0), status: "arrived")
        end

        it "is invalid" do
          admission = build(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 4, 1, 9, 0), status: "admitted")

          expect(admission).not_to be_valid
          expect(admission.errors[:admission_start])
            .to include("conflicts with another arrived or admitted admission -- discharge or cancel that one first.")
        end
      end

      context "when the existing occupying admission is discharged" do
        before do
          create(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 1, 9, 0), status: "discharged")
        end

        it "is valid" do
          admission = build(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 4, 1, 9, 0), status: "admitted")

          expect(admission).to be_valid
        end
      end

      context "when the admission being validated is itself only scheduled" do
        before do
          create(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 1, 9, 0), status: "arrived")
        end

        it "is valid, even though the patient has an ongoing occupying admission elsewhere" do
          admission = build(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 4, 1, 9, 0), status: "scheduled")

          expect(admission).to be_valid
        end
      end

      context "revalidating an already-persisted occupying admission" do
        it "does not conflict with itself" do
          admission = create(:admission, organization: organization, patient: patient,
            admission_start: Time.zone.local(2026, 3, 1, 9, 0), status: "arrived")

          expect(admission).to be_valid
        end
      end
    end

    describe "organization consistency" do
      context "when the patient and facility belong to different organizations" do
        it "is invalid" do
          facility = build(:facility)
          admission = build(:admission, facility: facility)

          expect(admission).not_to be_valid
          expect(admission.errors[:facility]).to include("must belong to the patient's organization")
        end
      end

      context "when the patient and doctor belong to different organizations" do
        it "is invalid" do
          doctor = build(:user)
          admission = build(:admission, doctor: doctor)

          expect(admission).not_to be_valid
          expect(admission.errors[:doctor]).to include("must belong to the patient's organization")
        end
      end

      context "when the patient and notes_updated_by belong to different organizations" do
        it "is invalid" do
          notes_updated_by = build(:user)
          admission = build(:admission, notes_updated_by: notes_updated_by)

          expect(admission).not_to be_valid
          expect(admission.errors[:notes_updated_by]).to include("must belong to the patient's organization")
        end
      end
    end
  end

  describe "status" do
    it "defaults to scheduled" do
      admission = create(:admission)

      expect(admission.status).to eq("scheduled")
    end

    it "rejects an invalid status" do
      admission = build(:admission)

      expect { admission.status = "invalid" }.to raise_error(ArgumentError)
    end
  end

  describe "#advance_status" do
    context "when the admission day is in the future" do
      it "does not advance the status" do
        admission = create(:admission, admission_start: 1.day.from_now)

        expect(admission.advance_status).to be_falsy
        expect(admission).to be_scheduled
      end
    end

    context "when the admission day is today" do
      it "advances from scheduled to arrived" do
        admission = create(:admission)

        expect(admission.advance_status).to be_truthy
        expect(admission).to be_arrived
      end
    end

    context "when the admission is already discharged" do
      it "does not change the status" do
        admission = create(:admission, status: "discharged")

        expect(admission.advance_status).to be_falsy
        expect(admission).to be_discharged
      end
    end

    context "when the admission is cancelled" do
      it "does not change the status" do
        admission = create(:admission, status: "cancelled")

        expect(admission.advance_status).to be_falsy
        expect(admission).to be_cancelled
      end
    end

    context "when admission_start is 'today' in IST but 'yesterday' in UTC" do
      it "advances the status" do
        # 1am IST on March 5 is 7:30pm UTC on March 4 — a UTC-based comparison
        # would wrongly see this admission_start as still in the future.
        travel_to(Time.zone.local(2026, 3, 5, 1, 0, 0)) do
          admission = create(:admission, admission_start: Time.current)

          expect(admission.advance_status).to be_truthy
          expect(admission).to be_arrived
        end
      end
    end
  end

  describe "#revert_status" do
    context "when the admission is scheduled" do
      it "does not change the status" do
        admission = create(:admission, status: "scheduled")

        expect(admission.revert_status).to be_falsy
        expect(admission).to be_scheduled
      end
    end

    context "when the admission is cancelled" do
      it "does not change the status" do
        admission = create(:admission, status: "cancelled")

        expect(admission.revert_status).to be_falsy
        expect(admission).to be_cancelled
      end
    end

    context "when the admission is admitted" do
      it "reverts the status" do
        admission = create(:admission, status: "admitted")

        expect(admission.revert_status).to be_truthy
        expect(admission).to be_arrived
      end
    end

    context "when the admission is discharged and no conflicting admission exists" do
      it "reverts the status" do
        admission = create(:admission, status: "discharged")

        expect(admission.revert_status).to be_truthy
        expect(admission).to be_admitted
      end
    end

    context "when the admission is already discharged and an occupying admission exists on another day" do
      it "does not change the status" do
        admission = create(:admission, organization: organization, patient: patient,
          admission_start: Time.zone.local(2026, 3, 5, 9, 0), status: "discharged")
        create(:admission, organization: organization, patient: patient,
          admission_start: Time.zone.local(2026, 4, 1, 9, 0), status: "arrived")

        expect(admission.revert_status).to be_falsy
        expect(admission.errors[:admission_start])
          .to include("conflicts with another arrived or admitted admission -- discharge or cancel that one first.")
        expect(admission.reload).to be_discharged
      end
    end
  end

  describe "#cancel" do
    context "when the admission is not scheduled" do
      it "does not change the status" do
        admission = create(:admission, status: "arrived")

        expect(admission.cancel).to be_falsy
        expect(admission).to be_arrived
      end
    end

    context "when the admission is scheduled" do
      it "cancels" do
        admission = create(:admission, status: "scheduled")

        expect(admission.cancel).to be_truthy
        expect(admission).to be_cancelled
      end
    end
  end

  describe "#uncancel" do
    context "when the admission is not cancelled" do
      it "does not change the status" do
        admission = create(:admission, status: "arrived")

        expect(admission.uncancel).to be_falsy
        expect(admission).to be_arrived
      end
    end

    context "when the admission is cancelled" do
      it "uncancels" do
        admission = create(:admission, status: "cancelled")

        expect(admission.uncancel).to be_truthy
        expect(admission).to be_scheduled
      end
    end

    context "when the admission is cancelled and a same-day scheduled admission exists" do
      it "does not change the status" do
        admission = create(:admission, organization: organization, patient: patient,
          admission_start: Time.zone.local(2026, 3, 5, 9, 0), status: "cancelled")
        create(:admission, organization: organization, patient: patient,
          admission_start: Time.zone.local(2026, 3, 5, 15, 0), status: "scheduled")

        expect(admission.uncancel).to be_falsy
        expect(admission.errors[:admission_start]).to include("conflicts with another admission the same day")
        expect(admission.reload).to be_cancelled
      end
    end
  end
end
