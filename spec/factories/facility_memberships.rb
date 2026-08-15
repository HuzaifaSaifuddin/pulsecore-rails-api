FactoryBot.define do
  factory :facility_membership do
    transient do
      organization { create(:organization) }
    end

    user { create(:user, organization: organization) }
    facility { create(:facility, organization: organization) }
  end
end
