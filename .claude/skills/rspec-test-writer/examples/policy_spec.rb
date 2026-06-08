# Example: Pundit policy spec. Test each action method (returns a boolean) and
# the Scope inner class (resolves a relation). Set up actors with UserPartyRole.
#
# WHY this shape: mirrors spec/policies/pitch_policy_spec.rb. Replace Pitch with
# the resource under test and adjust the role/state edges to the real rules.

require "rails_helper"

RSpec.describe PitchPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:creator)      { create(:user) }
  let(:member)       { create(:user) }
  let(:admin)        { create(:user) }
  let(:non_member)   { create(:user) }

  before do
    UserPartyRole.create!(user: creator, party: organization, role: "member")
    UserPartyRole.create!(user: member,  party: organization, role: "member")
    UserPartyRole.create!(user: admin,   party: organization, role: "admin")
  end

  let(:draft_pitch) { create(:pitch, user: creator, organization: organization) }
  let(:ready_pitch) do
    p = create(:pitch, user: creator, organization: organization)
    p.state_machine.transition_to!(:ready_for_betting)
    p
  end

  describe "#show?" do
    it "allows any organization member" do
      expect(described_class.new(member, draft_pitch).show?).to be true
    end

    it "prevents a non-member" do
      expect(described_class.new(non_member, draft_pitch).show?).to be false
    end

    it "allows a user who only holds a team role in the org" do
      team_member = create(:user)
      team = create(:team, organization: organization)
      UserPartyRole.create!(user: team_member, party: team, role: "member")
      expect(described_class.new(team_member, draft_pitch).show?).to be true
    end

    it "prevents a user who only holds a project role" do
      project_member = create(:user)
      team = create(:team, organization: organization)
      project = create(:project, team: team)
      UserPartyRole.create!(user: project_member, party: project, role: "member")
      expect(described_class.new(project_member, draft_pitch).show?).to be false
    end
  end

  describe "#update?" do
    it "allows the creator on a draft pitch" do
      expect(described_class.new(creator, draft_pitch).update?).to be true
    end

    it "prevents the creator once the pitch leaves draft" do
      expect(described_class.new(creator, ready_pitch).update?).to be false
    end

    it "allows an admin regardless of state" do
      expect(described_class.new(admin, draft_pitch).update?).to be true
      expect(described_class.new(admin, ready_pitch).update?).to be true
    end
  end

  describe "Scope" do
    let!(:own)        { create(:pitch, user: creator, organization: organization) }
    let!(:deleted)    { create(:pitch, user: creator, organization: organization).tap(&:soft_delete) }
    let!(:other_org)  { create(:pitch, user: creator, organization: create(:organization)) }

    it "includes pitches in the user's organization" do
      resolved = described_class::Scope.new(creator, Pitch).resolve
      expect(resolved).to include(own)
    end

    it "excludes soft-deleted pitches" do
      resolved = described_class::Scope.new(creator, Pitch).resolve
      expect(resolved).not_to include(deleted)
    end

    it "excludes pitches from other organizations" do
      resolved = described_class::Scope.new(creator, Pitch).resolve
      expect(resolved).not_to include(other_org)
    end
  end
end
