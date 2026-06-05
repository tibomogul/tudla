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

    it "busts members' member_organizations cache on restore" do
      team.soft_delete
      expect(user.member_organizations).to eq([]) # warms the cache while deleted

      team.restore

      expect(user.member_organizations).to eq([ org_a ])
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

  describe "pruning orphaned pitch co-authorships on soft delete" do
    let(:organization) { create(:organization) }
    let(:team) { create(:team, organization: organization) }
    let(:co_author) { create(:user) }
    let(:pitch) { create(:pitch, organization: organization) }

    after { co_author.bust_organizations_cache }

    context "when the team was the co-author's only membership path" do
      before do
        UserPartyRole.create!(user: co_author, party: team, role: "member")
        PitchCoAuthor.create!(pitch: pitch, user: co_author)
      end

      it "removes the co-author rows for the org's pitches" do
        team.soft_delete
        expect(PitchCoAuthor.where(pitch: pitch)).to be_empty
      end

      it "records a PaperTrail destroy version for each pruned row" do
        expect { team.soft_delete }
          .to change { PaperTrail::Version.where(item_type: "PitchCoAuthor", event: "destroy").count }.by(1)
      end
    end

    context "when the co-author still belongs to the org via a direct role" do
      before do
        UserPartyRole.create!(user: co_author, party: team, role: "member")
        UserPartyRole.create!(user: co_author, party: organization, role: "member")
        PitchCoAuthor.create!(pitch: pitch, user: co_author)
      end

      it "keeps the co-author rows" do
        team.soft_delete
        expect(PitchCoAuthor.where(pitch: pitch).pluck(:user_id)).to contain_exactly(co_author.id)
      end
    end
  end
end
