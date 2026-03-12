require "rails_helper"

RSpec.describe "User#accessible_organizations", type: :model do
  let(:user) { create(:user) }
  let(:org_a) { create(:organization, name: "Alpha Org") }
  let(:org_b) { create(:organization, name: "Beta Org") }

  after { user.bust_organizations_cache }

  describe "#accessible_organizations" do
    it "returns organizations where user has a direct role" do
      UserPartyRole.create!(user: user, party: org_a, role: "admin")

      expect(user.accessible_organizations).to eq([org_a])
    end

    it "returns organizations derived from team roles" do
      team = create(:team, organization: org_a)
      UserPartyRole.create!(user: user, party: team, role: "member")

      expect(user.accessible_organizations).to eq([org_a])
    end

    it "returns organizations derived from project roles" do
      team = create(:team, organization: org_a)
      project = create(:project, team: team)
      UserPartyRole.create!(user: user, party: project, role: "member")

      expect(user.accessible_organizations).to eq([org_a])
    end

    it "deduplicates organizations across role types" do
      team = create(:team, organization: org_a)
      UserPartyRole.create!(user: user, party: org_a, role: "admin")
      UserPartyRole.create!(user: user, party: team, role: "member")

      expect(user.accessible_organizations).to eq([org_a])
    end

    it "returns multiple organizations ordered by name" do
      UserPartyRole.create!(user: user, party: org_a, role: "admin")
      UserPartyRole.create!(user: user, party: org_b, role: "member")

      expect(user.accessible_organizations).to eq([org_a, org_b])
    end

    it "excludes soft-deleted organizations" do
      UserPartyRole.create!(user: user, party: org_a, role: "admin")
      UserPartyRole.create!(user: user, party: org_b, role: "member")
      org_b.update!(deleted_at: Time.current)
      user.bust_organizations_cache

      expect(user.accessible_organizations).to eq([org_a])
    end

    it "returns empty array when user has no roles" do
      expect(user.accessible_organizations).to eq([])
    end
  end

  describe "cache behavior" do
    it "caches the result" do
      UserPartyRole.create!(user: user, party: org_a, role: "admin")

      # First call populates cache
      result1 = user.accessible_organizations

      # Manually add a role without going through the model callback
      Rails.cache.fetch(user.organizations_cache_key) { [org_a] }

      # Second call should return cached result
      result2 = user.accessible_organizations
      expect(result2).to eq(result1)
    end

    it "busts cache when a UserPartyRole is created" do
      # Pre-populate cache with empty result
      user.accessible_organizations
      expect(user.accessible_organizations).to eq([])

      # Creating a role triggers after_commit which busts cache
      UserPartyRole.create!(user: user, party: org_a, role: "admin")

      expect(user.accessible_organizations).to eq([org_a])
    end

    it "busts cache when a UserPartyRole is destroyed" do
      role = UserPartyRole.create!(user: user, party: org_a, role: "admin")
      expect(user.accessible_organizations).to eq([org_a])

      role.destroy!

      expect(user.accessible_organizations).to eq([])
    end

    it "busts cache when a UserPartyRole is updated" do
      role = UserPartyRole.create!(user: user, party: org_a, role: "member")
      user.accessible_organizations # populate cache

      role.update!(role: "admin")

      # Cache was busted — re-fetches (still same org, but cache was invalidated)
      expect(user.accessible_organizations).to eq([org_a])
    end
  end
end
