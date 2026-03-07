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
  end

  describe "validations" do
    it "requires title" do
      pitch = build(:pitch, title: nil, user: user, organization: organization)
      expect(pitch).not_to be_valid
    end

    it "validates appetite inclusion" do
      expect(build(:pitch, appetite: 2, user: user, organization: organization)).to be_valid
      expect(build(:pitch, appetite: 6, user: user, organization: organization)).to be_valid
      expect(build(:pitch, appetite: 3, user: user, organization: organization)).not_to be_valid
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

    it "cannot transition draft → bet directly" do
      expect(pitch.state_machine.can_transition_to?(:bet)).to be false
    end

    it "cannot transition draft → rejected directly" do
      expect(pitch.state_machine.can_transition_to?(:rejected)).to be false
    end
  end

  describe ".visible_to" do
    let(:other_user) { create(:user) }
    let!(:draft_pitch) { create(:pitch, user: user, organization: organization) }
    let!(:ready_pitch) { create(:pitch, user: other_user, organization: organization) }

    before do
      ready_pitch.update_column(:status, "ready_for_betting")
    end

    it "shows draft pitches only to creator" do
      expect(Pitch.visible_to(user)).to include(draft_pitch)
      expect(Pitch.visible_to(other_user)).not_to include(draft_pitch)
    end

    it "shows ready_for_betting pitches to everyone" do
      expect(Pitch.visible_to(user)).to include(ready_pitch)
      expect(Pitch.visible_to(other_user)).to include(ready_pitch)
    end

    it "shows bet pitches to everyone" do
      bet_pitch = create(:pitch, user: other_user, organization: organization)
      bet_pitch.state_machine.transition_to!(:ready_for_betting)
      bet_pitch.state_machine.transition_to!(:bet)
      expect(Pitch.visible_to(user)).to include(bet_pitch)
    end

    it "shows rejected pitches to everyone" do
      rejected_pitch = create(:pitch, user: other_user, organization: organization)
      rejected_pitch.state_machine.transition_to!(:ready_for_betting)
      rejected_pitch.state_machine.transition_to!(:rejected)
      expect(Pitch.visible_to(user)).to include(rejected_pitch)
    end
  end

  describe "#appetite_label" do
    it "returns 'Small Batch' for 2 weeks" do
      pitch = build(:pitch, appetite: 2, user: user, organization: organization)
      expect(pitch.appetite_label).to eq("Small Batch")
    end

    it "returns 'Big Batch' for 6 weeks" do
      expect(pitch.appetite_label).to eq("Big Batch")
    end

    it "returns custom label for other values" do
      pitch = build(:pitch, appetite: 4, user: user, organization: organization)
      expect(pitch.appetite_label).to eq("4 weeks")
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
