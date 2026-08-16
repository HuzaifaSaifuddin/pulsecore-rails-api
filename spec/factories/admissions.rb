FactoryBot.define do
  factory :admission do
    transient do
      organization { create(:organization) }
    end

    patient { association :patient, organization: organization }
    facility { association :facility, organization: organization }
    doctor { association :user, organization: organization }
    admission_start { Time.current }
    admission_end { admission_start && admission_start + 1.day }

    trait :with_notes do
      notes { "Needs Assistance" }
      notes_updated_by { association :user, organization: organization }
      notes_updated_at { Time.current }
    end
  end
end
