require "rails_helper"

RSpec.describe "CORS", type: :request do
  it "allows the configured SPA origin with credentials" do
    process :options, "/api/v1/facilities", headers: {
      "Origin" => "http://localhost:5173",
      "Access-Control-Request-Method" => "GET"
    }

    expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:5173")
    expect(response.headers["Access-Control-Allow-Credentials"]).to eq("true")
  end

  it "does not allow an arbitrary origin" do
    process :options, "/api/v1/facilities", headers: {
      "Origin" => "http://evil.example.com",
      "Access-Control-Request-Method" => "GET"
    }

    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end
end
