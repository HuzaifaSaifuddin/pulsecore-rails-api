FactoryBot.define do
  factory :facility do
    sequence(:name) { |n| "Facility #{n}" }
    organization
  end
end
