require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "is invalid without an email" do
      user = build(:user, email: nil)

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    context "when the email is already taken" do
      before { create(:user, email: "jane@example.com") }

      it "is invalid" do
        user = build(:user, email: "jane@example.com")

        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("has already been taken")
      end
    end

    it "is invalid without a first name" do
      user = build(:user, first_name: nil)

      expect(user).not_to be_valid
      expect(user.errors[:first_name]).to include("can't be blank")
    end

    it "is invalid without a last name" do
      user = build(:user, last_name: nil)

      expect(user).not_to be_valid
      expect(user.errors[:last_name]).to include("can't be blank")
    end

    it "is invalid without a role" do
      user = build(:user, role: nil)

      expect(user).not_to be_valid
      expect(user.errors[:role]).to include("can't be blank")
    end

    it "is invalid without an organization" do
      user = build(:user, organization: nil)

      expect(user).not_to be_valid
      expect(user.errors[:organization]).to include("must exist")
    end

    it "rejects a role outside the allowed set" do
      user = build(:user)

      expect { user.role = "superuser" }.to raise_error(ArgumentError)
    end
  end

  describe "associations" do
    it "belongs to an organization" do
      organization = create(:organization)
      user = create(:user, organization: organization)

      expect(user.organization).to eq organization
    end

    it "optionally belongs to a default facility" do
      user = build(:user, default_facility: nil)

      expect(user).to be_valid
    end

    it "has many facilities through facility memberships" do
      facility_membership = create(:facility_membership)

      expect(facility_membership.user.facilities).to contain_exactly(facility_membership.facility)
    end
  end

  describe "#full_name" do
    it "joins first and last name" do
      user = build(:user, first_name: "Jane", last_name: "Doe")

      expect(user.full_name).to eq "Jane Doe"
    end
  end
end
