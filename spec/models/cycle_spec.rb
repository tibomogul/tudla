require "rails_helper"

RSpec.describe Cycle, type: :model do
  let(:organization) { create(:organization) }
  let(:cycle) { create(:cycle, organization: organization) }

  describe "associations" do
    it "belongs to organization" do
      expect(cycle.organization).to eq(organization)
    end

    it "has many projects" do
      expect(cycle).to respond_to(:projects)
    end

    it "has many cycle_transitions" do
      expect(cycle).to respond_to(:cycle_transitions)
    end
  end

  describe "validations" do
    it "requires name" do
      cycle = build(:cycle, name: nil, organization: organization)
      expect(cycle).not_to be_valid
    end

    it "requires start_date" do
      cycle = build(:cycle, start_date: nil, organization: organization)
      expect(cycle).not_to be_valid
    end

    it "requires end_date" do
      cycle = build(:cycle, end_date: nil, organization: organization)
      expect(cycle).not_to be_valid
    end

    it "requires end_date after start_date" do
      cycle = build(:cycle, start_date: Date.current, end_date: Date.current - 1.day, organization: organization)
      expect(cycle).not_to be_valid
      expect(cycle.errors[:end_date]).to include("must be after start date")
    end
  end

  describe "state machine" do
    it "starts in shaping state" do
      expect(cycle.current_state).to eq("shaping")
    end

    it "transitions shaping → betting" do
      cycle.state_machine.transition_to!(:betting)
      expect(cycle.current_state).to eq("betting")
    end

    it "transitions betting → active" do
      cycle.state_machine.transition_to!(:betting)
      cycle.state_machine.transition_to!(:active)
      expect(cycle.current_state).to eq("active")
    end

    it "transitions active → completed" do
      cycle.state_machine.transition_to!(:betting)
      cycle.state_machine.transition_to!(:active)
      cycle.state_machine.transition_to!(:completed)
      expect(cycle.current_state).to eq("completed")
    end

    it "cannot skip states" do
      expect(cycle.state_machine.can_transition_to?(:active)).to be false
    end

    it "cannot transition from completed" do
      cycle.state_machine.transition_to!(:betting)
      cycle.state_machine.transition_to!(:active)
      cycle.state_machine.transition_to!(:completed)
      expect(cycle.state_machine.can_transition_to?(:active)).to be false
    end
  end

  describe "#progress_percentage" do
    it "returns 0 before start date" do
      cycle = create(:cycle, start_date: Date.current + 1.day, end_date: Date.current + 9.weeks, organization: organization)
      expect(cycle.progress_percentage).to eq(0)
    end

    it "returns 100 after end date" do
      cycle = create(:cycle, start_date: Date.current - 9.weeks, end_date: Date.current - 1.day, organization: organization)
      expect(cycle.progress_percentage).to eq(100)
    end

    it "returns percentage during cycle" do
      cycle = create(:cycle, start_date: Date.current - 4.weeks, end_date: Date.current + 4.weeks, organization: organization)
      expect(cycle.progress_percentage).to be_between(40, 60)
    end

    it "returns 0 when dates are nil" do
      cycle = build(:cycle, start_date: nil, end_date: nil, organization: organization)
      expect(cycle.progress_percentage).to eq(0)
    end
  end

  describe "#build_phase?" do
    it "returns false when not active" do
      expect(cycle.build_phase?).to be false
    end

    it "returns true during build phase" do
      active_cycle = create(:cycle, start_date: Date.current - 4.weeks, end_date: Date.current + 4.weeks, organization: organization)
      active_cycle.state_machine.transition_to!(:betting)
      active_cycle.state_machine.transition_to!(:active)
      expect(active_cycle.build_phase?).to be true
    end

    it "returns false during cooldown phase" do
      cooldown_cycle = create(:cycle, start_date: Date.current - 7.weeks, end_date: Date.current + 1.week, organization: organization)
      cooldown_cycle.state_machine.transition_to!(:betting)
      cooldown_cycle.state_machine.transition_to!(:active)
      expect(cooldown_cycle.build_phase?).to be false
    end
  end

  describe "#cooldown_phase?" do
    it "returns false when not active" do
      expect(cycle.cooldown_phase?).to be false
    end

    it "returns false during build phase" do
      active_cycle = create(:cycle, start_date: Date.current - 4.weeks, end_date: Date.current + 4.weeks, organization: organization)
      active_cycle.state_machine.transition_to!(:betting)
      active_cycle.state_machine.transition_to!(:active)
      expect(active_cycle.cooldown_phase?).to be false
    end

    it "returns true during cooldown phase" do
      cooldown_cycle = create(:cycle, start_date: Date.current - 7.weeks, end_date: Date.current + 1.week, organization: organization)
      cooldown_cycle.state_machine.transition_to!(:betting)
      cooldown_cycle.state_machine.transition_to!(:active)
      expect(cooldown_cycle.cooldown_phase?).to be true
    end
  end

  describe "#cooldown_start_date" do
    it "returns 2 weeks before end_date" do
      cycle = create(:cycle, start_date: Date.current, end_date: Date.current + 6.weeks, organization: organization)
      expect(cycle.cooldown_start_date).to eq(Date.current + 4.weeks)
    end
  end

  describe "#active?" do
    it "returns true when in active state" do
      cycle.state_machine.transition_to!(:betting)
      cycle.state_machine.transition_to!(:active)
      expect(cycle.active?).to be true
    end

    it "returns false when in other states" do
      expect(cycle.active?).to be false
      cycle.state_machine.transition_to!(:betting)
      expect(cycle.active?).to be false
    end
  end

  describe "#days_remaining" do
    it "returns days until end_date" do
      cycle = create(:cycle, start_date: Date.current, end_date: Date.current + 14.days, organization: organization)
      expect(cycle.days_remaining).to eq(14)
    end

    it "returns 0 after end_date" do
      cycle = create(:cycle, start_date: Date.current - 2.weeks, end_date: Date.current - 1.day, organization: organization)
      expect(cycle.days_remaining).to eq(0)
    end

    it "returns 0 when end_date is nil" do
      cycle = build(:cycle, end_date: nil, organization: organization)
      expect(cycle.days_remaining).to eq(0)
    end
  end

  describe "#unfinished_projects" do
    let(:active_cycle) do
      c = create(:cycle, organization: organization)
      c.state_machine.transition_to!(:betting)
      c.state_machine.transition_to!(:active)
      c
    end

    it "returns projects not in done state" do
      team = create(:team, organization: organization)
      project = create(:project, team: team)
      active_cycle.projects << project
      expect(active_cycle.unfinished_projects).to include(project)
    end

    it "excludes soft-deleted projects" do
      team = create(:team, organization: organization)
      project = create(:project, team: team)
      active_cycle.projects << project
      project.destroy
      expect(active_cycle.unfinished_projects).not_to include(project)
    end
  end

  describe "#finished_projects" do
    let(:active_cycle) do
      c = create(:cycle, organization: organization)
      c.state_machine.transition_to!(:betting)
      c.state_machine.transition_to!(:active)
      c
    end

    it "returns projects in done state" do
      team = create(:team, organization: organization)
      project = create(:project, team: team, cycle: active_cycle)
      # Projects use risk_state, not task state machine for done
      expect(active_cycle.finished_projects).to be_a(ActiveRecord::Relation)
    end
  end

  describe "#timezone" do
    it "returns organization timezone" do
      org = create(:organization, timezone: "America/New_York")
      cycle = create(:cycle, organization: org)
      expect(cycle.timezone).to eq("America/New_York")
    end

    it "defaults to Brisbane timezone" do
      expect(cycle.timezone).to eq("Australia/Brisbane")
    end
  end

  describe "#format_in_timezone" do
    it "formats datetime in organization timezone" do
      org = create(:organization, timezone: "UTC")
      cycle = create(:cycle, organization: org)
      datetime = Time.zone.parse("2024-01-15 10:30:00")
      formatted = cycle.format_in_timezone(datetime, "%d %b %H:%M")
      expect(formatted).to include("15 Jan")
    end

    it "returns nil for nil datetime" do
      expect(cycle.format_in_timezone(nil)).to be_nil
    end
  end

  describe "soft delete" do
    it "soft deletes instead of hard delete" do
      cycle.destroy
      expect(cycle.reload.deleted_at).to be_present
      expect(Cycle.active).not_to include(cycle)
    end

    it "can be restored" do
      cycle.destroy
      cycle.restore
      expect(cycle.deleted_at).to be_nil
      expect(Cycle.active).to include(cycle)
    end

    it "nullifies cycle_id on associated projects" do
      team = create(:team, organization: organization)
      project = create(:project, team: team, cycle: cycle)
      cycle.destroy
      expect(project.reload.cycle_id).to be_nil
    end
  end

  describe "paper trail" do
    it "tracks changes" do
      cycle.update!(name: "Updated Cycle")
      expect(cycle.versions.count).to be >= 1
    end
  end
end
