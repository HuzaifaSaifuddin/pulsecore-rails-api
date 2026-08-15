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
end
