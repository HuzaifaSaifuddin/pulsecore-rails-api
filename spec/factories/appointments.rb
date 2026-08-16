FactoryBot.define do
  factory :appointment do
    transient do
      organization { create(:organization) }
    end

    patient { association :patient, organization: organization }
    facility { association :facility, organization: organization }
    doctor { association :user, organization: organization }
    scheduled_start { Time.current }
    scheduled_end { scheduled_start && scheduled_start + 1.hour }

    trait :with_notes do
      notes { "Needs Assistance" }
      notes_updated_by { association :user, organization: organization }
      notes_updated_at { Time.current }
    end
  end
end
