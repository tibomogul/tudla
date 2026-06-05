require 'rails_helper'

RSpec.describe Team, type: :model do
  describe "member cache busting" do
    let(:org_a) { create(:organization, name: "Alpha Org") }
    let(:org_b) { create(:organization, name: "Beta Org") }
    let(:team) { create(:team, organization: org_a) }
    let(:user) { create(:user) }

    before { UserPartyRole.create!(user: user, party: team, role: "member") }
    after { user.bust_organizations_cache }

    it "busts members' member_organizations cache on soft delete" do
      expect(user.member_organizations).to eq([ org_a ]) # warms the cache

      team.soft_delete

      expect(user.member_organizations).to eq([])
    end

    it "busts members' member_organizations cache when reassigned to another org" do
      expect(user.member_organizations).to eq([ org_a ]) # warms the cache

      team.update!(organization: org_b)

      expect(user.member_organizations).to eq([ org_b ])
    end

    it "does not bust caches for an unrelated update" do
      expect(team).not_to receive(:bust_member_caches)
      team.update!(name: "Renamed Team")
    end
  end
end
