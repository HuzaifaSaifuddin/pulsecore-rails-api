require "rails_helper"

RSpec.describe "Api::V1::Admissions", type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:facility) { create(:facility, organization: organization) }
  let(:other_facility) { create(:facility, organization: organization) }
  let(:password) { "Password123" }
  let(:patient) { create(:patient, organization: organization) }
  let(:other_patient) { create(:patient, organization: organization) }

  let!(:doctor) do
    create(:user, organization: organization, password: password, role: "doctor", default_facility: facility)
  end

  before { create(:facility_membership, user: doctor, facility: facility) }

  describe "GET /api/v1/admissions" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/admissions", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when signed in but no current facility is set" do
      let!(:no_facility_doctor) { create(:user, organization: organization, password: password, role: "doctor") }

      it "returns conflict" do
        sign_in_as(no_facility_doctor, password: password)

        get "/api/v1/admissions", as: :json

        expect(response).to have_http_status(:conflict)
      end
    end

    context "when signed in with a current facility" do
      let!(:todays_admission) do
        create(:admission, organization: organization, patient: patient, facility: facility,
          admission_start: Time.zone.now.change(hour: 10))
      end
      let!(:other_facility_admission) do
        create(:admission, organization: organization, patient: other_patient, facility: other_facility,
          admission_start: Time.zone.now.change(hour: 11))
      end

      it "returns only today's admissions at the current facility" do
        sign_in_as(doctor, password: password)

        get "/api/v1/admissions", as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["admissions"].pluck("id")).to contain_exactly(todays_admission.id)
      end
    end
  end

  describe "POST /api/v1/admissions" do
    it "creates an admission fixed to the current facility, even for a non-admin" do
      sign_in_as(doctor, password: password)

      post "/api/v1/admissions", params: {
        admission: { patient_id: patient.id, admission_start: Time.zone.now.change(hour: 14).iso8601, notes: "Observation" }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["admission"]).to include(
        "facility_id" => facility.id, "status" => "scheduled", "notes" => "Observation"
      )
      expect(response.parsed_body["admission"]["notes_updated_by_id"]).to eq(doctor.id)
    end

    it "returns validation errors for a patient from another organization" do
      foreign_patient = create(:patient, organization: other_organization)
      sign_in_as(doctor, password: password)

      post "/api/v1/admissions", params: {
        admission: { patient_id: foreign_patient.id, admission_start: Time.zone.now.iso8601 }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Facility must belong to the patient's organization")
    end
  end

  describe "PATCH /api/v1/admissions/:id" do
    let!(:admission) { create(:admission, organization: organization, patient: patient, facility: facility) }
    let!(:other_facility_admission) do
      create(:admission, organization: organization, patient: other_patient, facility: other_facility)
    end

    it "updates an admission and ignores an attempt to change status directly" do
      sign_in_as(doctor, password: password)

      patch "/api/v1/admissions/#{admission.id}", params: {
        admission: { notes: "Stable", status: "discharged" }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["admission"]["notes"]).to eq("Stable")
      expect(response.parsed_body["admission"]["status"]).to eq("scheduled")
    end

    it "returns not found for an admission at a facility the user cannot access" do
      sign_in_as(doctor, password: password)

      patch "/api/v1/admissions/#{other_facility_admission.id}", params: {
        admission: { notes: "Hijacked" }
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/admissions/:id/advance_status" do
    it "advances a today-dated admission to the next status" do
      admission = create(:admission, organization: organization, patient: patient, facility: facility,
        admission_start: Time.zone.now.change(hour: 9))
      sign_in_as(doctor, password: password)

      post "/api/v1/admissions/#{admission.id}/advance_status", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["admission"]["status"]).to eq("arrived")
    end

    it "blocks a second admission from becoming occupying while one is already arrived/admitted" do
      occupying = create(:admission, organization: organization, patient: patient, facility: facility,
        admission_start: Time.zone.now.change(hour: 9), status: "arrived")
      scheduled = create(:admission, organization: organization, patient: patient, facility: facility,
        admission_start: 2.days.ago)
      sign_in_as(doctor, password: password)

      post "/api/v1/admissions/#{scheduled.id}/advance_status", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].first).to match(/arrived or admitted/)
      expect(occupying.reload).to be_arrived
    end

    it "returns not found for an admission at a facility the user cannot access" do
      inaccessible = create(:admission, organization: organization, patient: other_patient, facility: other_facility)
      sign_in_as(doctor, password: password)

      post "/api/v1/admissions/#{inaccessible.id}/advance_status", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/admissions/:id/cancel" do
    it "cancels a scheduled admission" do
      admission = create(:admission, organization: organization, patient: patient, facility: facility)
      sign_in_as(doctor, password: password)

      post "/api/v1/admissions/#{admission.id}/cancel", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["admission"]["status"]).to eq("cancelled")
    end
  end

  describe "POST /api/v1/admissions/:id/uncancel" do
    it "uncancels a cancelled admission" do
      admission = create(:admission, organization: organization, patient: patient, facility: facility, status: "cancelled")
      sign_in_as(doctor, password: password)

      post "/api/v1/admissions/#{admission.id}/uncancel", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["admission"]["status"]).to eq("scheduled")
    end
  end
end
