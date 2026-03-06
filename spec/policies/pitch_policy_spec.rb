require "rails_helper"

RSpec.describe PitchPolicy, type: :policy do
  let(:organization) { create(:organization) }
  let(:creator) { create(:user) }
  let(:member) { create(:user) }
  let(:admin) { create(:user) }
  let(:non_member) { create(:user) }

  before do
    UserPartyRole.create!(user: creator, party: organization, role: "member")
    UserPartyRole.create!(user: member, party: organization, role: "member")
    UserPartyRole.create!(user: admin, party: organization, role: "admin")
  end

  let(:draft_pitch) { create(:pitch, user: creator, organization: organization) }
  let(:ready_pitch) do
    p = create(:pitch, user: creator, organization: organization)
    p.state_machine.transition_to!(:ready_for_betting)
    p
  end

  describe "#index?" do
    it "allows anyone" do
      expect(described_class.new(non_member, draft_pitch).index?).to be true
    end
  end

  describe "#show?" do
    it "allows creator to see own draft pitch" do
      expect(described_class.new(creator, draft_pitch).show?).to be true
    end

    it "prevents non-creator member from seeing draft pitch" do
      expect(described_class.new(member, draft_pitch).show?).to be false
    end

    it "allows member to see non-draft pitch" do
      expect(described_class.new(member, ready_pitch).show?).to be true
    end

    it "allows admin to see non-draft pitch" do
      expect(described_class.new(admin, ready_pitch).show?).to be true
    end

    it "prevents non-member from seeing any pitch" do
      expect(described_class.new(non_member, ready_pitch).show?).to be false
    end
  end

  describe "#create?" do
    it "allows organization member" do
      pitch = Pitch.new(organization: organization)
      expect(described_class.new(creator, pitch).create?).to be true
    end

    it "prevents non-member" do
      pitch = Pitch.new(organization: organization)
      expect(described_class.new(non_member, pitch).create?).to be false
    end

    it "allows user who is member of any org when pitch has no org set" do
      pitch = Pitch.new
      expect(described_class.new(creator, pitch).create?).to be true
    end

    it "prevents user with no org memberships when pitch has no org set" do
      pitch = Pitch.new
      expect(described_class.new(non_member, pitch).create?).to be false
    end
  end

  describe "#update?" do
    it "allows creator to update own draft pitch" do
      expect(described_class.new(creator, draft_pitch).update?).to be true
    end

    it "prevents creator from updating non-draft pitch" do
      expect(described_class.new(creator, ready_pitch).update?).to be false
    end

    it "prevents non-creator member from updating draft pitch" do
      expect(described_class.new(member, draft_pitch).update?).to be false
    end

    it "allows admin to update any pitch regardless of state" do
      expect(described_class.new(admin, draft_pitch).update?).to be true
      expect(described_class.new(admin, ready_pitch).update?).to be true
    end
  end

  describe "#destroy?" do
    it "allows creator to destroy own draft pitch" do
      expect(described_class.new(creator, draft_pitch).destroy?).to be true
    end

    it "prevents creator from destroying non-draft pitch" do
      expect(described_class.new(creator, ready_pitch).destroy?).to be false
    end

    it "prevents non-creator from destroying draft pitch" do
      expect(described_class.new(member, draft_pitch).destroy?).to be false
    end

    it "prevents admin from destroying pitch they did not create" do
      expect(described_class.new(admin, draft_pitch).destroy?).to be false
    end
  end

  describe "#submit?" do
    it "allows creator to submit own draft pitch" do
      expect(described_class.new(creator, draft_pitch).submit?).to be true
    end

    it "prevents non-creator from submitting" do
      expect(described_class.new(member, draft_pitch).submit?).to be false
    end

    it "prevents submitting non-draft pitch" do
      expect(described_class.new(creator, ready_pitch).submit?).to be false
    end
  end

  describe "#bet?" do
    it "allows admin" do
      expect(described_class.new(admin, ready_pitch).bet?).to be true
    end

    it "prevents non-admin member" do
      expect(described_class.new(member, ready_pitch).bet?).to be false
    end

    it "prevents creator who is not admin" do
      expect(described_class.new(creator, ready_pitch).bet?).to be false
    end
  end

  describe "#reject?" do
    it "allows admin" do
      expect(described_class.new(admin, ready_pitch).reject?).to be true
    end

    it "prevents non-admin member" do
      expect(described_class.new(member, ready_pitch).reject?).to be false
    end
  end

  describe "Scope" do
    let!(:own_draft) { create(:pitch, user: creator, organization: organization) }
    let!(:other_draft) { create(:pitch, user: member, organization: organization) }
    let!(:ready) do
      p = create(:pitch, user: member, organization: organization)
      p.state_machine.transition_to!(:ready_for_betting)
      p
    end
    let!(:deleted_pitch) do
      p = create(:pitch, user: creator, organization: organization)
      p.destroy
      p
    end
    let!(:other_org_pitch) do
      other_org = create(:organization)
      create(:pitch, user: creator, organization: other_org)
    end

    it "includes own draft pitches" do
      resolved = described_class::Scope.new(creator, Pitch).resolve
      expect(resolved).to include(own_draft)
    end

    it "excludes other users' draft pitches" do
      resolved = described_class::Scope.new(creator, Pitch).resolve
      expect(resolved).not_to include(other_draft)
    end

    it "includes non-draft pitches from other users" do
      resolved = described_class::Scope.new(creator, Pitch).resolve
      expect(resolved).to include(ready)
    end

    it "excludes soft-deleted pitches" do
      resolved = described_class::Scope.new(creator, Pitch).resolve
      expect(resolved).not_to include(deleted_pitch)
    end

    it "excludes pitches from other organizations" do
      resolved = described_class::Scope.new(creator, Pitch).resolve
      expect(resolved).not_to include(other_org_pitch)
    end
  end
end
