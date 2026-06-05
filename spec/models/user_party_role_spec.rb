require 'rails_helper'

RSpec.describe UserPartyRole, type: :model do
  describe "pruning orphaned pitch co-authorships on role removal" do
    let(:organization) { create(:organization) }
    let(:creator) { create(:user) }
    let(:co_author) { create(:user) }
    let(:pitch) { create(:pitch, organization: organization, user: creator) }

    after { co_author.bust_organizations_cache }

    def co_author_ids_for(pitch)
      PitchCoAuthor.where(pitch: pitch).pluck(:user_id)
    end

    context "when the removed role was the user's only membership path" do
      let!(:org_role) { UserPartyRole.create!(user: co_author, party: organization, role: "member") }

      before { PitchCoAuthor.create!(pitch: pitch, user: co_author) }

      it "removes the user's co-author rows for that org's pitches" do
        org_role.destroy
        expect(co_author_ids_for(pitch)).to be_empty
      end

      it "records a PaperTrail destroy version for each pruned row" do
        expect { org_role.destroy }
          .to change { PaperTrail::Version.where(item_type: "PitchCoAuthor", event: "destroy").count }.by(1)
      end

      it "leaves co-author rows for pitches in other orgs untouched" do
        other_org = create(:organization)
        UserPartyRole.create!(user: co_author, party: other_org, role: "member")
        other_pitch = create(:pitch, organization: other_org)
        PitchCoAuthor.create!(pitch: other_pitch, user: co_author)

        org_role.destroy

        expect(co_author_ids_for(other_pitch)).to contain_exactly(co_author.id)
      end
    end

    context "when the user still belongs to the org via another path" do
      let(:team) { create(:team, organization: organization) }
      let!(:org_role) { UserPartyRole.create!(user: co_author, party: organization, role: "member") }

      before do
        UserPartyRole.create!(user: co_author, party: team, role: "member")
        PitchCoAuthor.create!(pitch: pitch, user: co_author)
      end

      it "keeps the co-author rows" do
        org_role.destroy
        expect(co_author_ids_for(pitch)).to contain_exactly(co_author.id)
      end
    end

    context "when the removed role is a project-only role" do
      let(:team) { create(:team, organization: organization) }
      let(:project) { create(:project, team: team) }
      let!(:project_role) { UserPartyRole.create!(user: co_author, party: project, role: "member") }

      before { PitchCoAuthor.create!(pitch: pitch, user: co_author) }

      it "is a no-op (project roles never granted pitch visibility)" do
        project_role.destroy
        expect(co_author_ids_for(pitch)).to contain_exactly(co_author.id)
      end
    end
  end
end
