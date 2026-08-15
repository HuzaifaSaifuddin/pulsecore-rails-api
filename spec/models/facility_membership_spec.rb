require "rails_helper"

RSpec.describe FacilityMembership, type: :model do
  describe "validations" do
    it "is invalid without a user" do
      membership = build(:facility_membership, user: nil)

      expect(membership).not_to be_valid
      expect(membership.errors[:user]).to include("must exist")
    end

    it "is invalid without a facility" do
      membership = build(:facility_membership, facility: nil)

      expect(membership).not_to be_valid
      expect(membership.errors[:facility]).to include("must exist")
    end

    context "when the user is already a member of the facility" do
      let(:organization) { create(:organization) }
      let(:user) { create(:user, organization: organization) }
      let(:facility) { create(:facility, organization: organization) }

      before { create(:facility_membership, user: user, facility: facility) }

      it "is invalid" do
        membership = build(:facility_membership, user: user, facility: facility)

        expect(membership).not_to be_valid
        expect(membership.errors[:facility_id]).to include("has already been taken")
      end
    end
  end

  describe "associations" do
    it "makes the facility accessible via user.facilities" do
      facility_membership = create(:facility_membership)

      expect(facility_membership.user.reload.facilities).to include(facility_membership.facility)
    end
  end

  describe "accessible_facilities cache invalidation" do
    around do |example|
      cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = cache
    end

    it "invalidates the user's cache when a membership is created" do
      organization = create(:organization)
      user = create(:user, organization: organization, role: "doctor")
      facility = create(:facility, organization: organization)

      expect(user.accessible_facilities).to be_empty

      create(:facility_membership, user: user, facility: facility)

      expect(user.accessible_facilities).to contain_exactly(facility)
    end

    it "invalidates the user's cache when a membership is destroyed" do
      organization = create(:organization)
      user = create(:user, organization: organization, role: "doctor")
      facility = create(:facility, organization: organization)
      membership = create(:facility_membership, user: user, facility: facility)

      expect(user.accessible_facilities).to contain_exactly(facility)

      membership.destroy!

      expect(user.accessible_facilities).to be_empty
    end
  end
end
