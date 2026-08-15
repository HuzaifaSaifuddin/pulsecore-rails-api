FactoryBot.define do
  factory :organization do
    sequence(:name) { |n| "Organization #{n}" }
    email { "admin@example.com" }
    phone_number { "555-0100" }
  end
end
