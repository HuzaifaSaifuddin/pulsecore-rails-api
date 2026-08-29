require "rails_helper"

RSpec.describe "Api::V1::Me", type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:password) { "Password123" }

  describe "GET /api/v1/me" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/me", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when signed in with a default facility set" do
      let!(:facility) { create(:facility, organization: organization) }
      let!(:other_facility) { create(:facility, organization: organization) }
      let!(:admin) do
        create(:user, organization: organization, password: password, role: "org_admin", default_facility: facility)
      end

      it "returns the current user, current facility, and every accessible facility" do
        sign_in_as(admin, password: password)

        get "/api/v1/me", as: :json

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["user"]).to eq(
          {
            "id" => admin.id,
            "email" => admin.email,
            "first_name" => admin.first_name,
            "last_name" => admin.last_name,
            "role" => admin.role,
            "organization_id" => organization.id,
            "default_facility_id" => facility.id,
            "facility_ids" => []
          }
        )
        expect(body["current_facility"]).to eq(
          { "id" => facility.id, "name" => facility.name, "organization_id" => organization.id }
        )
        expect(body["accessible_facilities"]).to contain_exactly(
          { "id" => facility.id, "name" => facility.name, "organization_id" => organization.id },
          { "id" => other_facility.id, "name" => other_facility.name, "organization_id" => organization.id }
        )
      end
    end

    context "when signed in with no default facility set" do
      let!(:doctor) { create(:user, organization: organization, password: password, role: "doctor") }

      it "returns null for current_facility" do
        sign_in_as(doctor, password: password)

        get "/api/v1/me", as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["current_facility"]).to be_nil
        expect(response.parsed_body["accessible_facilities"]).to eq([])
      end
    end
  end

  describe "PATCH /api/v1/me" do
    let!(:facility) { create(:facility, organization: organization) }
    let!(:other_facility) { create(:facility, organization: organization) }
    let!(:doctor) { create(:user, organization: organization, password: password, role: "doctor") }

    before { doctor.facilities << [ facility, other_facility ] }

    it "sets the current facility to one the user can access" do
      sign_in_as(doctor, password: password)

      patch "/api/v1/me", params: { user: { default_facility_id: other_facility.id } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["current_facility"]["id"]).to eq(other_facility.id)
      expect(response.parsed_body["user"]["default_facility_id"]).to eq(other_facility.id)
      expect(doctor.reload.default_facility_id).to eq(other_facility.id)
    end

    it "rejects a facility the user cannot access" do
      sign_in_as(doctor, password: password)
      unreachable = create(:facility, organization: organization)

      patch "/api/v1/me", params: { user: { default_facility_id: unreachable.id } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(doctor.reload.default_facility_id).to be_nil
    end

    it "rejects a facility from another organization" do
      sign_in_as(doctor, password: password)
      foreign = create(:facility, organization: other_organization)

      patch "/api/v1/me", params: { user: { default_facility_id: foreign.id } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unauthorized when not signed in" do
      patch "/api/v1/me", params: { user: { default_facility_id: facility.id } }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
