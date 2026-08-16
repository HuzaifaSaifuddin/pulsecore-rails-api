require "rails_helper"

RSpec.describe "Users::Signups", type: :request do
  describe "POST /api/v1/signup" do
    let(:valid_params) do
      {
        organization: { name: "Sunrise Clinics", email: "info@sunrise.com", phone_number: "9800011122" },
        user: { email: "admin@sunrise.com", password: "Password123", first_name: "Sam", last_name: "Rise" }
      }
    end

    it "requires no authentication" do
      post "/api/v1/signup", params: valid_params, as: :json

      expect(response).to have_http_status(:created)
    end

    it "atomically creates an organization, a same-named starter facility, and an org_admin user" do
      post "/api/v1/signup", params: valid_params, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body

      expect(body["organization"]).to include("name" => "Sunrise Clinics")
      expect(body["facility"]).to include("name" => "Sunrise Clinics", "organization_id" => body["organization"]["id"])
      expect(body["user"]).to include(
        "email" => "admin@sunrise.com",
        "role" => "org_admin",
        "organization_id" => body["organization"]["id"],
        "default_facility_id" => body["facility"]["id"]
      )
    end

    it "signs the new admin in" do
      post "/api/v1/signup", params: valid_params, as: :json

      expect(response.cookies["_pulse_core_session"]).to be_present
    end

    context "when the organization name is already taken" do
      before { create(:organization, name: "Sunrise Clinics") }

      it "returns validation errors and creates nothing" do
        expect {
          post "/api/v1/signup", params: valid_params, as: :json
        }.to change(Facility, :count).by(0).and change(User, :count).by(0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to include("Name has already been taken")
      end
    end

    context "when the admin email is already taken" do
      before { create(:user, email: "admin@sunrise.com") }

      it "returns validation errors and rolls back the organization and facility too" do
        expect {
          post "/api/v1/signup", params: valid_params, as: :json
        }.to change(Organization, :count).by(0).and change(Facility, :count).by(0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body["errors"]).to include("Email has already been taken")
        expect(Organization.exists?(name: "Sunrise Clinics")).to be false
      end
    end
  end
end
