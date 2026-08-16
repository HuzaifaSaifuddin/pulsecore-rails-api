FactoryBot.define do
  factory :patient do
    organization
    sequence(:mrn) { |n| "P-%06d" % n }
    first_name { "Jane" }
    last_name { "Doe" }
    date_of_birth { "2006-08-16" }
    gender { "male" }
    phone_number { "9876543210" }
    email { "jane.doe@example.com" }
  end
end
