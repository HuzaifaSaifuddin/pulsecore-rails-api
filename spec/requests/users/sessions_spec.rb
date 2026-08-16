require "rails_helper"

RSpec.describe "Users::Sessions", type: :request do
  let(:organization) { create(:organization) }
  let(:password) { "Password123" }
  let!(:user) { create(:user, organization: organization, password: password) }

  describe "POST /users/sign_in" do
    context "with valid credentials" do
      it "returns the signed-in user and sets the session cookie" do
        post "/users/sign_in",
          params: { user: { email: user.email, password: password } },
          as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["user"]).to eq(
          "id" => user.id,
          "email" => user.email,
          "first_name" => user.first_name,
          "last_name" => user.last_name,
          "role" => user.role,
          "organization_id" => user.organization_id,
          "default_facility_id" => user.default_facility_id
        )
        expect(response.cookies["_pulse_core_session"]).to be_present
      end
    end

    context "with an incorrect password" do
      it "returns an error without signing in" do
        post "/users/sign_in",
          params: { user: { email: user.email, password: "wrongpassword" } },
          as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body["error"]).to be_present
      end
    end
  end

  describe "DELETE /users/sign_out" do
    context "when signed in" do
      it "signs out with no content" do
        sign_in_as(user, password: password)

        delete "/users/sign_out", as: :json

        expect(response).to have_http_status(:no_content)
        expect(response.body).to be_empty
      end
    end

    context "when not signed in" do
      it "returns unauthorized" do
        delete "/users/sign_out", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
