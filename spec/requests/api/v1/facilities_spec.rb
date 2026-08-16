require "rails_helper"

RSpec.describe "Api::V1::Facilities", type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:password) { "Password123" }
  let!(:admin) { create(:user, organization: organization, password: password, role: "org_admin") }
  let!(:doctor) { create(:user, organization: organization, password: password, role: "doctor") }

  describe "GET /api/v1/facilities" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/facilities", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when signed in" do
      let!(:own_facility) { create(:facility, organization: organization) }
      let!(:other_facility) { create(:facility, organization: other_organization) }

      it "returns only facilities belonging to the current user's organization" do
        sign_in_as(doctor, password: password)

        get "/api/v1/facilities", as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["facilities"]).to contain_exactly(
          { "id" => own_facility.id, "name" => own_facility.name, "organization_id" => organization.id }
        )
      end
    end
  end

  describe "POST /api/v1/facilities" do
    context "when signed in as org_admin" do
      it "creates a facility scoped to the current user's organization" do
        sign_in_as(admin, password: password)

        post "/api/v1/facilities", params: { facility: { name: "New Wing" } }, as: :json

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["facility"]).to include(
          "name" => "New Wing", "organization_id" => organization.id
        )
      end

      it "returns validation errors for an invalid facility" do
        sign_in_as(admin, password: password)

        post "/api/v1/facilities", params: { facility: { name: "" } }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to include("Name can't be blank")
      end
    end

    context "when signed in as a non-admin" do
      it "returns forbidden" do
        sign_in_as(doctor, password: password)

        post "/api/v1/facilities", params: { facility: { name: "New Wing" } }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /api/v1/facilities/:id" do
    let!(:facility) { create(:facility, organization: organization) }
    let!(:other_facility) { create(:facility, organization: other_organization) }

    context "when signed in as org_admin" do
      it "updates a facility belonging to the current user's organization" do
        sign_in_as(admin, password: password)

        patch "/api/v1/facilities/#{facility.id}", params: { facility: { name: "Renamed" } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["facility"]).to include("name" => "Renamed")
      end

      it "ignores an attempt to reassign organization_id via params" do
        sign_in_as(admin, password: password)

        patch "/api/v1/facilities/#{facility.id}",
          params: { facility: { name: "Still Mine", organization_id: other_organization.id } },
          as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["facility"]["organization_id"]).to eq(organization.id)
      end

      it "returns not found for another organization's facility" do
        sign_in_as(admin, password: password)

        patch "/api/v1/facilities/#{other_facility.id}", params: { facility: { name: "Hijacked" } }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as a non-admin" do
      it "returns forbidden" do
        sign_in_as(doctor, password: password)

        patch "/api/v1/facilities/#{facility.id}", params: { facility: { name: "Renamed" } }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
