require "rails_helper"

RSpec.describe "Api::V1::Users", type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:password) { "Password123" }
  let!(:admin) { create(:user, organization: organization, password: password, role: "org_admin") }
  let!(:doctor) { create(:user, organization: organization, password: password, role: "doctor") }

  describe "GET /api/v1/users" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/users", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when signed in as a non-admin" do
      let!(:other_org_user) { create(:user, organization: other_organization) }

      it "returns only users belonging to the current user's organization, without leaking auth columns" do
        sign_in_as(doctor, password: password)

        get "/api/v1/users", as: :json

        expect(response).to have_http_status(:ok)
        user_ids = response.parsed_body["users"].pluck("id")
        expect(user_ids).to contain_exactly(admin.id, doctor.id)

        doctor_json = response.parsed_body["users"].find { |u| u["id"] == doctor.id }
        expect(doctor_json.keys).to contain_exactly(
          "id", "email", "first_name", "last_name", "role", "organization_id", "default_facility_id"
        )
      end
    end
  end

  describe "POST /api/v1/users" do
    context "when signed in as org_admin" do
      it "creates a user scoped to the current user's organization" do
        sign_in_as(admin, password: password)

        post "/api/v1/users", params: {
          user: { email: "newdoc@example.com", password: "Password123", first_name: "New", last_name: "Doc", role: "doctor" }
        }, as: :json

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["user"]).to include(
          "email" => "newdoc@example.com", "role" => "doctor", "organization_id" => organization.id
        )
      end

      it "returns validation errors for a duplicate email" do
        sign_in_as(admin, password: password)

        post "/api/v1/users", params: {
          user: { email: doctor.email, password: "Password123", first_name: "New", last_name: "Doc", role: "doctor" }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to include("Email has already been taken")
      end

      it "returns a clean error for an invalid role, instead of a 500" do
        sign_in_as(admin, password: password)

        post "/api/v1/users", params: {
          user: { email: "weird@example.com", password: "Password123", first_name: "New", last_name: "Doc", role: "superadmin" }
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to include("'superadmin' is not a valid role")
      end
    end

    context "when signed in as a non-admin" do
      it "returns forbidden" do
        sign_in_as(doctor, password: password)

        post "/api/v1/users", params: {
          user: { email: "sneaky@example.com", password: "Password123", first_name: "S", last_name: "D", role: "doctor" }
        }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not signed in" do
      it "returns unauthorized" do
        post "/api/v1/users", params: {
          user: { email: "nobody@example.com", password: "Password123", first_name: "N", last_name: "B", role: "doctor" }
        }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/users/:id" do
    let!(:staff) { create(:user, organization: organization, role: "receptionist") }
    let!(:other_org_user) { create(:user, organization: other_organization) }

    context "when signed in as org_admin" do
      it "updates a staff member's name and role" do
        sign_in_as(admin, password: password)

        patch "/api/v1/users/#{staff.id}", params: {
          user: { first_name: "Renamed", role: "doctor" }
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["user"]).to include("first_name" => "Renamed", "role" => "doctor")
      end

      it "does not permit changing email, password, or organization_id" do
        sign_in_as(admin, password: password)
        original_email = staff.email

        patch "/api/v1/users/#{staff.id}", params: {
          user: { last_name: "Fixed", email: "hijack@example.com", organization_id: other_organization.id }
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(staff.reload.email).to eq(original_email)
        expect(staff.organization_id).to eq(organization.id)
      end

      it "returns a clean error for an invalid role, instead of a 500" do
        sign_in_as(admin, password: password)

        patch "/api/v1/users/#{staff.id}", params: { user: { role: "superadmin" } }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to include("'superadmin' is not a valid role")
      end

      it "returns not found for a user in another organization" do
        sign_in_as(admin, password: password)

        patch "/api/v1/users/#{other_org_user.id}", params: { user: { first_name: "Hijacked" } }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed in as a non-admin" do
      it "returns forbidden" do
        sign_in_as(doctor, password: password)

        patch "/api/v1/users/#{staff.id}", params: { user: { first_name: "Nope" } }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when not signed in" do
      it "returns unauthorized" do
        patch "/api/v1/users/#{staff.id}", params: { user: { first_name: "Nope" } }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
