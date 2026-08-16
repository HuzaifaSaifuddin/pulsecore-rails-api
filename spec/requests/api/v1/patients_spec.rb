require "rails_helper"

RSpec.describe "Api::V1::Patients", type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:password) { "Password123" }
  let!(:receptionist) { create(:user, organization: organization, password: password, role: "receptionist") }
  let!(:doctor) { create(:user, organization: organization, password: password, role: "doctor") }

  describe "GET /api/v1/patients" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/patients", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when signed in" do
      let!(:own_patient) { create(:patient, organization: organization) }
      let!(:other_patient) { create(:patient, organization: other_organization) }

      it "returns only patients belonging to the current user's organization" do
        sign_in_as(receptionist, password: password)

        get "/api/v1/patients", as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["patients"].pluck("id")).to contain_exactly(own_patient.id)
      end
    end
  end

  describe "POST /api/v1/patients" do
    it "creates a patient scoped to the current user's organization, even for a non-admin" do
      sign_in_as(receptionist, password: password)

      post "/api/v1/patients", params: {
        patient: {
          first_name: "New", last_name: "Patient", date_of_birth: "1990-01-01",
          gender: "other", phone_number: "9123456789"
        }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["patient"]).to include("organization_id" => organization.id)
      expect(response.parsed_body["patient"]["mrn"]).to match(/\AP-\d{6}\z/)
    end

    it "ignores client-supplied mrn and organization_id" do
      sign_in_as(receptionist, password: password)

      post "/api/v1/patients", params: {
        patient: {
          first_name: "New", last_name: "Patient", date_of_birth: "1990-01-01",
          gender: "other", phone_number: "9123456789",
          mrn: "P-999999", organization_id: other_organization.id
        }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["patient"]["mrn"]).not_to eq("P-999999")
      expect(response.parsed_body["patient"]["organization_id"]).to eq(organization.id)
    end

    it "returns validation errors for an incomplete patient" do
      sign_in_as(receptionist, password: password)

      post "/api/v1/patients", params: { patient: { first_name: "New" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Last name can't be blank")
    end
  end

  describe "PATCH /api/v1/patients/:id" do
    let!(:patient) { create(:patient, organization: organization) }
    let!(:other_patient) { create(:patient, organization: other_organization) }

    it "updates a patient belonging to the current user's organization, even for a non-admin" do
      sign_in_as(doctor, password: password)

      patch "/api/v1/patients/#{patient.id}", params: { patient: { phone_number: "9111111111" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["patient"]["phone_number"]).to eq("9111111111")
    end

    it "returns not found for another organization's patient" do
      sign_in_as(doctor, password: password)

      patch "/api/v1/patients/#{other_patient.id}", params: { patient: { phone_number: "9111111111" } }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
