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
          "id", "email", "first_name", "last_name", "role", "organization_id", "default_facility_id",
          "facility_ids"
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

      it "assigns a single facility and makes it the default" do
        sign_in_as(admin, password: password)
        facility = create(:facility, organization: organization)

        post "/api/v1/users", params: {
          user: { email: "one@example.com", password: "Password123", first_name: "One", last_name: "Fac",
                  role: "doctor", facility_ids: [ facility.id ] }
        }, as: :json

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["user"]).to include(
          "facility_ids" => [ facility.id ], "default_facility_id" => facility.id
        )
      end

      it "assigns multiple facilities and leaves the default unset for a login-time pick" do
        sign_in_as(admin, password: password)
        facilities = create_list(:facility, 2, organization: organization)

        post "/api/v1/users", params: {
          user: { email: "many@example.com", password: "Password123", first_name: "Many", last_name: "Fac",
                  role: "doctor", facility_ids: facilities.map(&:id) }
        }, as: :json

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["user"]["facility_ids"]).to match_array(facilities.map(&:id))
        expect(response.parsed_body["user"]["default_facility_id"]).to be_nil
      end

      it "silently ignores a facility from another organization" do
        sign_in_as(admin, password: password)
        own = create(:facility, organization: organization)
        foreign = create(:facility, organization: other_organization)

        post "/api/v1/users", params: {
          user: { email: "mixed@example.com", password: "Password123", first_name: "Mix", last_name: "Fac",
                  role: "doctor", facility_ids: [ own.id, foreign.id ] }
        }, as: :json

        expect(response).to have_http_status(:created)
        expect(response.parsed_body["user"]["facility_ids"]).to eq([ own.id ])
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

      it "syncs facility memberships and sets the default when exactly one remains" do
        sign_in_as(admin, password: password)
        a, b = create_list(:facility, 2, organization: organization)
        staff.facilities << [ a, b ]

        patch "/api/v1/users/#{staff.id}", params: { user: { facility_ids: [ a.id ] } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["user"]["facility_ids"]).to eq([ a.id ])
        expect(response.parsed_body["user"]["default_facility_id"]).to eq(a.id)
      end

      it "keeps a still-valid default when several facilities are assigned" do
        sign_in_as(admin, password: password)
        a, b, c = create_list(:facility, 3, organization: organization)
        staff.facilities << a
        staff.update!(default_facility: a)

        patch "/api/v1/users/#{staff.id}", params: { user: { facility_ids: [ a.id, b.id, c.id ] } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["user"]["default_facility_id"]).to eq(a.id)
        expect(response.parsed_body["user"]["facility_ids"]).to match_array([ a.id, b.id, c.id ])
      end

      it "clears the default when the current facility is no longer assigned" do
        sign_in_as(admin, password: password)
        a, b, c = create_list(:facility, 3, organization: organization)
        staff.facilities << a
        staff.update!(default_facility: a)

        patch "/api/v1/users/#{staff.id}", params: { user: { facility_ids: [ b.id, c.id ] } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["user"]["default_facility_id"]).to be_nil
      end

      it "leaves memberships untouched when facility_ids is absent from the payload" do
        sign_in_as(admin, password: password)
        a = create(:facility, organization: organization)
        staff.facilities << a
        staff.update!(default_facility: a)

        patch "/api/v1/users/#{staff.id}", params: { user: { first_name: "Renamed" } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["user"]["facility_ids"]).to eq([ a.id ])
        expect(response.parsed_body["user"]["default_facility_id"]).to eq(a.id)
      end

      it "clears all memberships and the default when given an empty list" do
        sign_in_as(admin, password: password)
        a = create(:facility, organization: organization)
        staff.facilities << a
        staff.update!(default_facility: a)

        patch "/api/v1/users/#{staff.id}", params: { user: { facility_ids: [] } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["user"]["facility_ids"]).to eq([])
        expect(response.parsed_body["user"]["default_facility_id"]).to be_nil
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
