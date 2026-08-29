require "rails_helper"

RSpec.describe "Api::V1::Appointments", type: :request do
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

  describe "GET /api/v1/appointments" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/appointments", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when signed in but no current facility is set" do
      let!(:no_facility_doctor) { create(:user, organization: organization, password: password, role: "doctor") }

      it "returns conflict" do
        sign_in_as(no_facility_doctor, password: password)

        get "/api/v1/appointments", as: :json

        expect(response).to have_http_status(:conflict)
      end
    end

    context "when signed in with a current facility" do
      let!(:todays_appointment) do
        create(:appointment, organization: organization, patient: patient, facility: facility,
          scheduled_start: Time.zone.now.change(hour: 10))
      end
      let!(:other_day_appointment) do
        create(:appointment, organization: organization, patient: patient, facility: facility,
          scheduled_start: 3.days.from_now)
      end
      let!(:other_facility_appointment) do
        create(:appointment, organization: organization, patient: other_patient, facility: other_facility,
          scheduled_start: Time.zone.now.change(hour: 11))
      end

      it "returns only today's appointments at the current facility" do
        sign_in_as(doctor, password: password)

        get "/api/v1/appointments", as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["appointments"].pluck("id")).to contain_exactly(todays_appointment.id)
      end

      it "embeds the patient and doctor as nested objects" do
        sign_in_as(doctor, password: password)

        get "/api/v1/appointments", as: :json

        body = response.parsed_body["appointments"].first
        expect(body).not_to have_key("patient_id")
        expect(body).not_to have_key("doctor_id")
        expect(body["patient"]).to include(
          "id" => patient.id, "mrn" => patient.mrn, "first_name" => patient.first_name,
          "gender" => patient.gender
        )
        expect(body["doctor"]).to include("id" => todays_appointment.doctor_id, "role" => "doctor")
      end

      it "does not issue a query per appointment when serializing associations" do
        sign_in_as(doctor, password: password)
        get "/api/v1/appointments", as: :json # warm the per-request caches

        before_count = count_queries { get "/api/v1/appointments", as: :json }

        3.times do |i|
          create(:appointment, organization: organization, facility: facility,
            scheduled_start: Time.zone.now.change(hour: 8 + i))
        end
        after_count = count_queries { get "/api/v1/appointments", as: :json }

        expect(response.parsed_body["appointments"].size).to eq(4)
        expect(after_count).to eq(before_count)
      end

      it "supports filtering by an explicit date" do
        sign_in_as(doctor, password: password)

        get "/api/v1/appointments",
          params: { date: 3.days.from_now.to_date.iso8601 },
          headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["appointments"].pluck("id")).to contain_exactly(other_day_appointment.id)
      end
    end
  end

  describe "POST /api/v1/appointments" do
    it "creates an appointment fixed to the current facility, even for a non-admin" do
      sign_in_as(doctor, password: password)

      post "/api/v1/appointments", params: {
        appointment: { patient_id: patient.id, scheduled_start: Time.zone.now.change(hour: 14).iso8601, notes: "First visit" }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["appointment"]).to include(
        "facility_id" => facility.id, "status" => "scheduled", "notes" => "First visit"
      )
      expect(response.parsed_body["appointment"]["patient"]).to include("id" => patient.id, "mrn" => patient.mrn)
      expect(response.parsed_body["appointment"]["doctor"]).to be_nil
      expect(response.parsed_body["appointment"]["notes_updated_by_id"]).to eq(doctor.id)
    end

    it "returns conflict when no current facility is set" do
      no_facility_doctor = create(:user, organization: organization, password: password, role: "doctor")
      sign_in_as(no_facility_doctor, password: password)

      post "/api/v1/appointments", params: {
        appointment: { patient_id: patient.id, scheduled_start: Time.zone.now.iso8601 }
      }, as: :json

      expect(response).to have_http_status(:conflict)
    end

    it "returns validation errors for a patient from another organization" do
      foreign_patient = create(:patient, organization: other_organization)
      sign_in_as(doctor, password: password)

      post "/api/v1/appointments", params: {
        appointment: { patient_id: foreign_patient.id, scheduled_start: Time.zone.now.iso8601 }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Facility must belong to the patient's organization")
    end
  end

  describe "PATCH /api/v1/appointments/:id" do
    let!(:appointment) { create(:appointment, organization: organization, patient: patient, facility: facility) }
    let!(:other_facility_appointment) do
      create(:appointment, organization: organization, patient: other_patient, facility: other_facility)
    end

    it "updates an appointment and ignores an attempt to change status directly" do
      sign_in_as(doctor, password: password)

      patch "/api/v1/appointments/#{appointment.id}", params: {
        appointment: { notes: "Follow-up needed", status: "completed" }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["appointment"]["notes"]).to eq("Follow-up needed")
      expect(response.parsed_body["appointment"]["status"]).to eq("scheduled")
    end

    it "returns not found for an appointment at a facility the user cannot access" do
      sign_in_as(doctor, password: password)

      patch "/api/v1/appointments/#{other_facility_appointment.id}", params: {
        appointment: { notes: "Hijacked" }
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/appointments/:id/advance_status" do
    it "advances a today-dated appointment to the next status" do
      appointment = create(:appointment, organization: organization, patient: patient, facility: facility,
        scheduled_start: Time.zone.now.change(hour: 9))
      sign_in_as(doctor, password: password)

      post "/api/v1/appointments/#{appointment.id}/advance_status", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["appointment"]["status"]).to eq("arrived")
    end

    it "returns an error when the appointment is scheduled in the future" do
      appointment = create(:appointment, organization: organization, patient: patient, facility: facility,
        scheduled_start: 3.days.from_now)
      sign_in_as(doctor, password: password)

      post "/api/v1/appointments/#{appointment.id}/advance_status", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq([ "Unable to advance status" ])
    end

    it "returns not found for an appointment at a facility the user cannot access" do
      inaccessible = create(:appointment, organization: organization, patient: other_patient, facility: other_facility)
      sign_in_as(doctor, password: password)

      post "/api/v1/appointments/#{inaccessible.id}/advance_status", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/appointments/:id/revert_status" do
    it "reverts an appointment to the previous status" do
      appointment = create(:appointment, organization: organization, patient: patient, facility: facility,
        scheduled_start: Time.zone.now.change(hour: 9), status: "arrived")
      sign_in_as(doctor, password: password)

      post "/api/v1/appointments/#{appointment.id}/revert_status", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["appointment"]["status"]).to eq("scheduled")
    end

    it "returns an error when already at the initial status" do
      appointment = create(:appointment, organization: organization, patient: patient, facility: facility)
      sign_in_as(doctor, password: password)

      post "/api/v1/appointments/#{appointment.id}/revert_status", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq([ "Unable to revert status" ])
    end
  end

  describe "POST /api/v1/appointments/:id/cancel" do
    it "cancels a scheduled appointment" do
      appointment = create(:appointment, organization: organization, patient: patient, facility: facility)
      sign_in_as(doctor, password: password)

      post "/api/v1/appointments/#{appointment.id}/cancel", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["appointment"]["status"]).to eq("cancelled")
    end

    it "returns an error when the appointment is not scheduled" do
      appointment = create(:appointment, organization: organization, patient: patient, facility: facility,
        scheduled_start: Time.zone.now.change(hour: 9), status: "arrived")
      sign_in_as(doctor, password: password)

      post "/api/v1/appointments/#{appointment.id}/cancel", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq([ "Unable to cancel" ])
    end
  end

  describe "POST /api/v1/appointments/:id/uncancel" do
    it "uncancels a cancelled appointment" do
      appointment = create(:appointment, organization: organization, patient: patient, facility: facility, status: "cancelled")
      sign_in_as(doctor, password: password)

      post "/api/v1/appointments/#{appointment.id}/uncancel", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["appointment"]["status"]).to eq("scheduled")
    end

    it "returns an error when the appointment is not cancelled" do
      appointment = create(:appointment, organization: organization, patient: patient, facility: facility)
      sign_in_as(doctor, password: password)

      post "/api/v1/appointments/#{appointment.id}/uncancel", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to eq([ "Unable to uncancel" ])
    end
  end
end
