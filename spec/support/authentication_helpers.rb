module AuthenticationHelpers
  def sign_in_as(user, password:)
    post "/users/sign_in", params: { user: { email: user.email, password: password } }, as: :json
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
