require "rails_helper"

RSpec.describe Pitch, type: :model do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:pitch) { create(:pitch, user: user, organization: organization) }

  describe "associations" do
    it "belongs to user" do
      expect(pitch.user).to eq(user)
    end

    it "belongs to organization" do
      expect(pitch.organization).to eq(organization)
    end

    it "has many projects" do
      expect(pitch).to respond_to(:projects)
    end

    it "has many pitch_transitions" do
      expect(pitch).to respond_to(:pitch_transitions)
    end

    it "has many co_authors" do
      expect(pitch).to respond_to(:co_authors)
    end

    it "excludes soft-deleted users from co_authors" do
      active_co_author = create(:user)
      removed_co_author = create(:user)
      pitch.co_authors << active_co_author
      pitch.co_authors << removed_co_author
      removed_co_author.destroy

      expect(pitch.reload.co_authors).to contain_exactly(active_co_author)
    end
  end

  describe "validations" do
    it "requires title" do
      pitch = build(:pitch, title: nil, user: user, organization: organization)
      expect(pitch).not_to be_valid
    end

    it "validates appetite inclusion in 1..6" do
      (1..6).each do |n|
        expect(build(:pitch, appetite: n, user: user, organization: organization)).to be_valid
      end
      expect(build(:pitch, appetite: 0, user: user, organization: organization)).not_to be_valid
      expect(build(:pitch, appetite: 7, user: user, organization: organization)).not_to be_valid
    end
  end

  describe "state machine" do
    it "starts in draft state" do
      expect(pitch.current_state).to eq("draft")
    end

    it "transitions draft → ready_for_betting" do
      pitch.state_machine.transition_to!(:ready_for_betting)
      expect(pitch.current_state).to eq("ready_for_betting")
    end

    it "transitions ready_for_betting → bet" do
      pitch.state_machine.transition_to!(:ready_for_betting)
      pitch.state_machine.transition_to!(:bet)
      expect(pitch.current_state).to eq("bet")
    end

    it "transitions ready_for_betting → rejected" do
      pitch.state_machine.transition_to!(:ready_for_betting)
      pitch.state_machine.transition_to!(:rejected)
      expect(pitch.current_state).to eq("rejected")
    end

    it "allows rework: rejected → draft" do
      pitch.state_machine.transition_to!(:ready_for_betting)
      pitch.state_machine.transition_to!(:rejected)
      pitch.state_machine.transition_to!(:draft)
      expect(pitch.current_state).to eq("draft")
    end

    it "allows pull back: ready_for_betting → draft" do
      pitch.state_machine.transition_to!(:ready_for_betting)
      pitch.state_machine.transition_to!(:draft)
      expect(pitch.current_state).to eq("draft")
    end

    it "treats bet as terminal" do
      pitch.state_machine.transition_to!(:ready_for_betting)
      pitch.state_machine.transition_to!(:bet)
      expect(pitch.state_machine.can_transition_to?(:draft)).to be false
      expect(pitch.state_machine.can_transition_to?(:ready_for_betting)).to be false
    end

    it "cannot transition draft → bet directly" do
      expect(pitch.state_machine.can_transition_to?(:bet)).to be false
    end

    it "cannot transition draft → rejected directly" do
      expect(pitch.state_machine.can_transition_to?(:rejected)).to be false
    end
  end

  describe ".authored_by" do
    let(:co_author) { create(:user) }
    let(:other_user) { create(:user) }
    let!(:own_pitch) { create(:pitch, user: user, organization: organization) }
    let!(:co_authored_pitch) do
      p = create(:pitch, user: other_user, organization: organization)
      p.co_authors << co_author
      p
    end
    let!(:unrelated_pitch) { create(:pitch, user: other_user, organization: organization) }

    it "includes pitches the user created" do
      expect(Pitch.authored_by(user)).to include(own_pitch)
    end

    it "includes pitches the user co-authors" do
      expect(Pitch.authored_by(co_author)).to include(co_authored_pitch)
    end

    it "excludes pitches the user neither created nor co-authors" do
      expect(Pitch.authored_by(user)).not_to include(co_authored_pitch, unrelated_pitch)
    end

    it "does not duplicate a pitch the user both created and co-authors" do
      own_pitch.co_authors << user
      result = Pitch.authored_by(user).to_a
      expect(result.count { |p| p.id == own_pitch.id }).to eq(1)
    end
  end

  describe ".rejected_in_cycle" do
    let(:cycle) { create(:cycle, organization: organization) }
    let(:other_cycle) { create(:cycle, organization: organization) }

    def reject_pitch(target_cycle_id)
      p = create(:pitch, user: user, organization: organization)
      p.state_machine.transition_to!(:ready_for_betting)
      p.state_machine.transition_to!(:rejected, cycle_id: target_cycle_id)
      p
    end

    it "includes pitches rejected on that cycle" do
      rejected_here = reject_pitch(cycle.id)
      expect(Pitch.rejected_in_cycle(cycle)).to include(rejected_here)
    end

    it "excludes pitches rejected on a different cycle" do
      rejected_elsewhere = reject_pitch(other_cycle.id)
      expect(Pitch.rejected_in_cycle(cycle)).not_to include(rejected_elsewhere)
    end

    it "excludes pitches rejected without a cycle stamp" do
      p = create(:pitch, user: user, organization: organization)
      p.state_machine.transition_to!(:ready_for_betting)
      p.state_machine.transition_to!(:rejected)
      expect(Pitch.rejected_in_cycle(cycle)).not_to include(p)
    end

    it "excludes a pitch reworked back to draft even if it was rejected on the cycle" do
      reworked = reject_pitch(cycle.id)
      reworked.state_machine.transition_to!(:draft)
      expect(Pitch.rejected_in_cycle(cycle)).not_to include(reworked)
    end
  end

  describe "#assignable_co_authors" do
    let(:other_member) { create(:user) }
    let(:another_member) { create(:user) }

    before do
      UserPartyRole.create!(user: user, party: organization, role: "member")
      UserPartyRole.create!(user: other_member, party: organization, role: "member")
      UserPartyRole.create!(user: another_member, party: organization, role: "member")
    end

    it "returns active organization members excluding the creator" do
      assignable = pitch.assignable_co_authors
      expect(assignable).to include(other_member, another_member)
      expect(assignable).not_to include(user)
    end

    it "includes a user who only holds a team role in the org" do
      team_member = create(:user)
      team = create(:team, organization: organization)
      UserPartyRole.create!(user: team_member, party: team, role: "member")
      expect(pitch.assignable_co_authors).to include(team_member)
    end

    it "excludes a user who only holds a project role" do
      project_member = create(:user)
      team = create(:team, organization: organization)
      project = create(:project, team: team)
      UserPartyRole.create!(user: project_member, party: project, role: "member")
      expect(pitch.assignable_co_authors).not_to include(project_member)
    end

    it "returns no users when the pitch has no organization" do
      new_pitch = Pitch.new(title: "No org")
      expect(new_pitch.assignable_co_authors).to be_empty
    end
  end

  describe "#sync_co_authors" do
    let(:member_a) { create(:user) }
    let(:member_b) { create(:user) }
    let(:outsider) { create(:user) }

    before do
      UserPartyRole.create!(user: member_a, party: organization, role: "member")
      UserPartyRole.create!(user: member_b, party: organization, role: "member")
    end

    it "adds the given assignable members as co-authors" do
      pitch.sync_co_authors([ member_a.id, member_b.id ])
      expect(pitch.reload.co_authors).to contain_exactly(member_a, member_b)
    end

    it "removes co-authors not in the given list" do
      pitch.sync_co_authors([ member_a.id, member_b.id ])
      pitch.sync_co_authors([ member_a.id ])
      expect(pitch.reload.co_authors).to contain_exactly(member_a)
    end

    it "ignores ids that are not assignable members" do
      pitch.sync_co_authors([ member_a.id, outsider.id, user.id ])
      expect(pitch.reload.co_authors).to contain_exactly(member_a)
    end

    it "clears all co-authors when given a blank list" do
      pitch.sync_co_authors([ member_a.id ])
      pitch.sync_co_authors(nil)
      expect(pitch.reload.co_authors).to be_empty
    end

    it "prunes an orphaned join row for a soft-deleted user via the unscoped join" do
      pitch.sync_co_authors([ member_a.id, member_b.id ])
      # Orphan the row directly (bypassing User#soft_delete's cascade) so we
      # exercise sync_co_authors' own unscoped reconciliation.
      member_b.update_column(:deleted_at, Time.current)

      pitch.sync_co_authors([ member_a.id ])

      expect(PitchCoAuthor.where(pitch: pitch).pluck(:user_id)).to contain_exactly(member_a.id)
    end

    it "is idempotent when re-run with the same ids" do
      pitch.sync_co_authors([ member_a.id, member_b.id ])
      expect {
        pitch.sync_co_authors([ member_a.id, member_b.id ])
      }.not_to change { PitchCoAuthor.where(pitch: pitch).count }
      expect(pitch.reload.co_authors).to contain_exactly(member_a, member_b)
    end

    it "tolerates a pre-existing row for an allowed id without raising" do
      PitchCoAuthor.create!(pitch: pitch, user: member_a)

      expect {
        pitch.sync_co_authors([ member_a.id, member_b.id ])
      }.not_to raise_error
      expect(pitch.reload.co_authors).to contain_exactly(member_a, member_b)
    end
  end

  describe "#appetite_label" do
    it "returns Small Batch label for 1-2 weeks" do
      expect(build(:pitch, appetite: 1, user: user, organization: organization).appetite_label).to eq("Small Batch (1w)")
      expect(build(:pitch, appetite: 2, user: user, organization: organization).appetite_label).to eq("Small Batch (2w)")
    end

    it "returns Medium Batch label for 3-4 weeks" do
      expect(build(:pitch, appetite: 3, user: user, organization: organization).appetite_label).to eq("Medium Batch (3w)")
      expect(build(:pitch, appetite: 4, user: user, organization: organization).appetite_label).to eq("Medium Batch (4w)")
    end

    it "returns Big Batch label for 5-6 weeks" do
      expect(build(:pitch, appetite: 5, user: user, organization: organization).appetite_label).to eq("Big Batch (5w)")
      expect(build(:pitch, appetite: 6, user: user, organization: organization).appetite_label).to eq("Big Batch (6w)")
    end
  end

  describe "#appetite_batch" do
    it "returns :small for 1-2 weeks" do
      expect(build(:pitch, appetite: 1, user: user, organization: organization).appetite_batch).to eq(:small)
      expect(build(:pitch, appetite: 2, user: user, organization: organization).appetite_batch).to eq(:small)
    end

    it "returns :medium for 3-4 weeks" do
      expect(build(:pitch, appetite: 3, user: user, organization: organization).appetite_batch).to eq(:medium)
      expect(build(:pitch, appetite: 4, user: user, organization: organization).appetite_batch).to eq(:medium)
    end

    it "returns :big for 5-6 weeks" do
      expect(build(:pitch, appetite: 5, user: user, organization: organization).appetite_batch).to eq(:big)
      expect(build(:pitch, appetite: 6, user: user, organization: organization).appetite_batch).to eq(:big)
    end
  end

  describe "#ingredients_complete?" do
    it "returns true when all ingredients present" do
      expect(pitch.ingredients_complete?).to be true
    end

    it "returns false when problem is missing" do
      pitch.problem = nil
      expect(pitch.ingredients_complete?).to be false
    end

    it "returns false when appetite is missing" do
      pitch.appetite = nil
      expect(pitch.ingredients_complete?).to be false
    end

    it "returns false when solution is missing" do
      pitch.solution = nil
      expect(pitch.ingredients_complete?).to be false
    end

    it "returns false when rabbit_holes is missing" do
      pitch.rabbit_holes = nil
      expect(pitch.ingredients_complete?).to be false
    end

    it "returns false when no_gos is missing" do
      pitch.no_gos = nil
      expect(pitch.ingredients_complete?).to be false
    end
  end

  describe "#time_in_current_state" do
    it "returns time since last transition" do
      pitch.state_machine.transition_to!(:ready_for_betting)
      expect(pitch.time_in_current_state).to be_a(Numeric)
      expect(pitch.time_in_current_state).to be >= 0
    end

    it "returns nil when no transitions exist" do
      new_pitch = Pitch.new(title: "Test", user: user, organization: organization)
      expect(new_pitch.time_in_current_state).to be_nil
    end
  end

  describe "#timezone" do
    it "returns organization timezone" do
      org = create(:organization, timezone: "America/Los_Angeles")
      pitch = create(:pitch, user: user, organization: org)
      expect(pitch.timezone).to eq("America/Los_Angeles")
    end

    it "defaults to Brisbane timezone" do
      expect(pitch.timezone).to eq("Australia/Brisbane")
    end
  end

  describe "#format_in_timezone" do
    it "formats datetime in organization timezone" do
      org = create(:organization, timezone: "UTC")
      pitch = create(:pitch, user: user, organization: org)
      datetime = Time.zone.parse("2024-01-15 10:30:00")
      formatted = pitch.format_in_timezone(datetime, "%d %b %H:%M")
      expect(formatted).to include("15 Jan")
    end

    it "returns nil for nil datetime" do
      expect(pitch.format_in_timezone(nil)).to be_nil
    end
  end

  describe "soft delete" do
    it "soft deletes instead of hard delete" do
      pitch.destroy
      expect(pitch.reload.deleted_at).to be_present
      expect(Pitch.active).not_to include(pitch)
    end

    it "can be restored" do
      pitch.destroy
      pitch.restore
      expect(pitch.deleted_at).to be_nil
      expect(Pitch.active).to include(pitch)
    end

    it "nullifies pitch_id on associated projects" do
      team = create(:team, organization: organization)
      project = create(:project, team: team, pitch: pitch)
      pitch.destroy
      expect(project.reload.pitch_id).to be_nil
    end

    it "destroys co-author join rows (honoring dependent: :destroy past update_column)" do
      co_author = create(:user)
      PitchCoAuthor.create!(pitch: pitch, user: co_author)

      expect { pitch.destroy }
        .to change { PitchCoAuthor.where(pitch: pitch).count }.from(1).to(0)
    end

    it "records a PaperTrail destroy version for each pruned co-author row" do
      PitchCoAuthor.create!(pitch: pitch, user: create(:user))

      expect { pitch.destroy }
        .to change { PaperTrail::Version.where(item_type: "PitchCoAuthor", event: "destroy").count }.by(1)
    end
  end

  describe "paper trail" do
    it "tracks changes" do
      pitch.update!(title: "Updated Pitch")
      expect(pitch.versions.count).to be >= 1
    end
  end

  describe "#current_state" do
    it "returns status column value when set" do
      pitch.update_column(:status, "ready_for_betting")
      expect(pitch.current_state).to eq("ready_for_betting")
    end

    it "falls back to state_machine when status is nil" do
      pitch.update_column(:status, nil)
      expect(pitch.current_state).to eq("draft")
    end
  end

  describe "Statesman query adapter" do
    let!(:draft_pitch) { create(:pitch, user: user, organization: organization) }
    let!(:ready_pitch) do
      p = create(:pitch, user: user, organization: organization)
      p.state_machine.transition_to!(:ready_for_betting)
      p
    end

    it "filters with .in_state" do
      expect(Pitch.in_state(:draft)).to include(draft_pitch)
      expect(Pitch.in_state(:draft)).not_to include(ready_pitch)
    end

    it "filters with .not_in_state" do
      expect(Pitch.not_in_state(:draft)).to include(ready_pitch)
      expect(Pitch.not_in_state(:draft)).not_to include(draft_pitch)
    end
  end

  describe "state machine after_transition callback" do
    it "updates the status column after transition" do
      pitch.state_machine.transition_to!(:ready_for_betting)
      pitch.reload
      expect(pitch.status).to eq("ready_for_betting")
    end
  end

  describe "delegated types" do
    it "can have notes through notable" do
      expect(pitch).to respond_to(:notes)
      expect(pitch).to respond_to(:notable)
    end

    it "can have links through linkable" do
      expect(pitch).to respond_to(:links)
      expect(pitch).to respond_to(:linkable)
    end

    it "can have attachments through attachable" do
      expect(pitch).to respond_to(:attachments)
      expect(pitch).to respond_to(:attachable)
    end
  end
end
