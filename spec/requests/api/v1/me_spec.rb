require "rails_helper"

RSpec.describe "Api::V1::Me", type: :request do
  let(:organization) { create(:organization) }
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
            "default_facility_id" => facility.id
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
end
