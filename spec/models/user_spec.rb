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

  describe "#accessible_facilities" do
    around do |example|
      cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = cache
    end

    it "allows org_admin to access every facility in their organization, membership or not" do
      organization = create(:organization)
      admin = create(:user, organization: organization, role: "org_admin")
      facility_with_membership = create(:facility, organization: organization)
      facility_without_membership = create(:facility, organization: organization)
      create(:facility_membership, user: admin, facility: facility_with_membership)

      expect(admin.accessible_facilities).to contain_exactly(facility_with_membership, facility_without_membership)
    end

    it "restricts a non-org_admin to only their explicit facility memberships" do
      organization = create(:organization)
      doctor = create(:user, organization: organization, role: "doctor")
      member_facility = create(:facility, organization: organization)
      create(:facility, organization: organization)
      create(:facility_membership, user: doctor, facility: member_facility)

      expect(doctor.accessible_facilities).to contain_exactly(member_facility)
    end

    it "caches the computed facility ids so a second call does not recompute them" do
      organization = create(:organization)
      admin = create(:user, organization: organization, role: "org_admin")
      create(:facility, organization: organization)

      expect(organization).to receive(:facilities).once.and_call_original

      admin.accessible_facilities
      admin.accessible_facilities
    end

    it "invalidates the cache when the user's role changes" do
      organization = create(:organization)
      user = create(:user, organization: organization, role: "doctor")
      member_facility = create(:facility, organization: organization)
      other_facility = create(:facility, organization: organization)
      create(:facility_membership, user: user, facility: member_facility)

      expect(user.accessible_facilities).to contain_exactly(member_facility)

      user.update!(role: "org_admin")

      expect(user.accessible_facilities).to contain_exactly(member_facility, other_facility)
    end

    it "does not invalidate the cache for an unrelated attribute change" do
      organization = create(:organization)
      user = create(:user, organization: organization, role: "org_admin")
      create(:facility, organization: organization)

      user.accessible_facilities

      expect(organization).not_to receive(:facilities)

      user.update!(first_name: "Updated")
      user.accessible_facilities
    end
  end
end
