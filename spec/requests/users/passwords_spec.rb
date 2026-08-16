require "rails_helper"

RSpec.describe "Users::Passwords", type: :request do
  let(:organization) { create(:organization) }
  let!(:user) { create(:user, organization: organization, password: "OldPassword123") }

  describe "POST /users/password" do
    it "returns a generic message for a registered email" do
      post "/users/password", params: { user: { email: user.email } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["message"]).to be_present
    end

    it "returns the identical message for an unregistered email (paranoid mode)" do
      registered_response = begin
        post "/users/password", params: { user: { email: user.email } }, as: :json
        response.parsed_body
      end

      post "/users/password", params: { user: { email: "nobody@nowhere.com" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(registered_response)
    end
  end

  describe "PATCH /users/password" do
    it "resets the password with a valid token and signs the user in" do
      token = user.send_reset_password_instructions

      patch "/users/password", params: {
        user: { reset_password_token: token, password: "NewPassword123", password_confirmation: "NewPassword123" }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["user"]).to include("id" => user.id)
      expect(response.cookies["_pulse_core_session"]).to be_present
      expect(user.reload.valid_password?("NewPassword123")).to be true
    end

    it "rejects an invalid token" do
      patch "/users/password", params: {
        user: { reset_password_token: "not-a-real-token", password: "NewPassword123", password_confirmation: "NewPassword123" }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to be_present
      expect(user.reload.valid_password?("OldPassword123")).to be true
    end

    it "rejects a mismatched password confirmation" do
      token = user.send_reset_password_instructions

      patch "/users/password", params: {
        user: { reset_password_token: token, password: "NewPassword123", password_confirmation: "Different123" }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Password confirmation doesn't match Password")
    end

    it "rejects reusing an already-consumed token" do
      token = user.send_reset_password_instructions
      patch "/users/password", params: {
        user: { reset_password_token: token, password: "NewPassword123", password_confirmation: "NewPassword123" }
      }, as: :json

      patch "/users/password", params: {
        user: { reset_password_token: token, password: "AnotherPassword123", password_confirmation: "AnotherPassword123" }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
