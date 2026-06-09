require "rails_helper"

RSpec.describe Project, type: :model do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }

  describe "associations" do
    it "has many scopes" do
      scope = create(:scope, project: project)
      expect(project.scopes).to include(scope)
    end

    it "has many tasks" do
      task = create(:task, project: project)
      expect(project.tasks).to include(task)
    end

    it "limits unscoped_tasks to tasks with no scope" do
      scope = create(:scope, project: project)
      scoped_task = create(:task, project: project, scope: scope)
      unscoped_task = create(:task, project: project)

      expect(project.unscoped_tasks).to include(unscoped_task)
      expect(project.unscoped_tasks).not_to include(scoped_task)
    end

    it "belongs to a team" do
      expect(project.team).to eq(team)
    end

    it "belongs to a pitch" do
      pitch = create(:pitch, organization: organization)
      project = create(:project, team: team, pitch: pitch)
      expect(project.pitch).to eq(pitch)
    end

    it "belongs to a cycle" do
      cycle = create(:cycle, organization: organization)
      project = create(:project, team: team, cycle: cycle)
      expect(project.cycle).to eq(cycle)
    end

    it "exposes users through user_party_roles" do
      user = create(:user)
      UserPartyRole.create!(user: user, party: project, role: "member")
      expect(project.users).to include(user)
    end
  end

  describe "after_create" do
    it "creates a subscribable record" do
      project = create(:project, team: team)
      expect(project.subscribable).to be_present
    end
  end

  describe "soft delete" do
    let!(:project) { create(:project, team: team) }

    it "excludes soft-deleted records from .active" do
      project.soft_delete
      expect(Project.active).not_to include(project)
      expect(project.deleted_at).to be_present
    end

    it "still finds soft-deleted records via .with_deleted" do
      project.soft_delete
      expect(Project.with_deleted).to include(project)
    end

    it "surfaces only soft-deleted records via .only_deleted" do
      other = create(:project, team: team)
      project.soft_delete
      expect(Project.only_deleted).to include(project)
      expect(Project.only_deleted).not_to include(other)
    end

    it "restores a soft-deleted record back into .active" do
      project.soft_delete
      project.restore
      expect(Project.active).to include(project)
      expect(project.deleted_at).to be_nil
    end
  end

  describe ".not_archived" do
    it "excludes archived projects but keeps active and done ones" do
      active_project = create(:project, team: team, lifecycle_state: "active")
      done_project = create(:project, team: team, lifecycle_state: "done")
      archived_project = create(:project, team: team, lifecycle_state: "archived")

      result = Project.not_archived
      expect(result).to include(active_project, done_project)
      expect(result).not_to include(archived_project)
    end
  end

  describe ".visible" do
    it "includes only active projects" do
      active_project = create(:project, team: team, lifecycle_state: "active")
      done_project = create(:project, team: team, lifecycle_state: "done")
      archived_project = create(:project, team: team, lifecycle_state: "archived")

      result = Project.visible
      expect(result).to include(active_project)
      expect(result).not_to include(done_project, archived_project)
    end
  end

  describe "risk state machine" do
    it "starts in the green state" do
      expect(project.risk_current_state).to eq("green")
    end

    it "transitions green -> yellow and persists to the risk_state column" do
      project.risk_state_machine.transition_to!(:yellow)
      expect(project.risk_state_machine.current_state).to eq("yellow")
      expect(project.reload.risk_state).to eq("yellow")
    end

    it "transitions green -> red" do
      project.risk_state_machine.transition_to!(:red)
      expect(project.reload.risk_state).to eq("red")
    end

    it "transitions yellow -> red -> green" do
      project.risk_state_machine.transition_to!(:yellow)
      project.risk_state_machine.transition_to!(:red)
      project.risk_state_machine.transition_to!(:green)
      expect(project.reload.risk_state).to eq("green")
    end

    it "forbids transitioning to the same state" do
      expect { project.risk_state_machine.transition_to!(:green) }
        .to raise_error(Statesman::TransitionFailedError)
    end

    it "risk_current_state reads the persisted column once set" do
      project.risk_state_machine.transition_to!(:yellow)
      expect(project.reload.risk_current_state).to eq("yellow")
    end
  end

  describe "#time_in_current_risk_state" do
    it "returns nil when there are no transitions yet" do
      expect(project.time_in_current_risk_state).to be_nil
    end

    it "returns the elapsed time since the last transition" do
      travel_to(Time.zone.local(2026, 1, 15, 9)) do
        project.risk_state_machine.transition_to!(:yellow)
      end

      travel_to(Time.zone.local(2026, 1, 15, 9, 30)) do
        expect(project.time_in_current_risk_state).to be_within(1.second).of(30.minutes)
      end
    end
  end

  describe "lifecycle state machine" do
    it "starts in the active state" do
      expect(project.current_lifecycle_state).to eq("active")
    end

    it "transitions active -> done and stamps done_at" do
      travel_to(Time.zone.local(2026, 1, 15, 9)) do
        project.lifecycle_state_machine.transition_to!(:done)
      end

      project.reload
      expect(project.lifecycle_state).to eq("done")
      expect(project.done_at).to be_within(1.second).of(Time.zone.local(2026, 1, 15, 9))
    end

    it "transitions active -> archived and stamps archived_at" do
      travel_to(Time.zone.local(2026, 1, 15, 9)) do
        project.lifecycle_state_machine.transition_to!(:archived)
      end

      project.reload
      expect(project.lifecycle_state).to eq("archived")
      expect(project.archived_at).to be_within(1.second).of(Time.zone.local(2026, 1, 15, 9))
    end

    it "forbids transitioning archived -> done directly" do
      project.lifecycle_state_machine.transition_to!(:archived)
      expect { project.lifecycle_state_machine.transition_to!(:done) }
        .to raise_error(Statesman::TransitionFailedError)
    end

    describe "predicates" do
      it "active? is true only in the active state" do
        expect(project.active?).to be true
        expect(project.done?).to be false
        expect(project.archived?).to be false
      end

      it "done? is true after transitioning to done" do
        project.lifecycle_state_machine.transition_to!(:done)
        project.reload
        expect(project.done?).to be true
        expect(project.active?).to be false
      end

      it "archived? is true after transitioning to archived" do
        project.lifecycle_state_machine.transition_to!(:archived)
        project.reload
        expect(project.archived?).to be true
      end
    end

    describe "#read_only?" do
      it "is false while active" do
        expect(project.read_only?).to be false
      end

      it "is true once done" do
        project.lifecycle_state_machine.transition_to!(:done)
        project.reload
        expect(project.read_only?).to be true
      end
    end

    describe "propagation to children" do
      let!(:scope) { create(:scope, project: project) }
      let!(:task) { create(:task, project: project, scope: scope) }

      it "propagates the lifecycle state to scopes and tasks on transition" do
        project.lifecycle_state_machine.transition_to!(:done)

        expect(scope.reload.project_lifecycle_state).to eq("done")
        expect(task.reload.project_lifecycle_state).to eq("done")
      end
    end
  end

  describe "#propagate_lifecycle_to_children!" do
    let!(:scope) { create(:scope, project: project) }
    let!(:task) { create(:task, project: project) }

    it "copies the project's lifecycle_state onto all child scopes and tasks" do
      project.update_column(:lifecycle_state, "archived")
      project.propagate_lifecycle_to_children!

      expect(scope.reload.project_lifecycle_state).to eq("archived")
      expect(task.reload.project_lifecycle_state).to eq("archived")
    end
  end

  describe "estimate cache rollups" do
    it "sums active task estimates onto the project cached_* columns" do
      create(:task, project: project, unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3)
      create(:task, project: project, unassisted_estimate: 20, ai_assisted_estimate: 15, actual_manhours: 8)

      project.reload
      expect(project.cached_unassisted_estimate).to eq(30)
      expect(project.cached_ai_assisted_estimate).to eq(20)
      expect(project.cached_actual_manhours).to eq(11)
    end

    it "starts at zero with no tasks" do
      expect(project.cached_unassisted_estimate).to eq(0)
      expect(project.cached_ai_assisted_estimate).to eq(0)
      expect(project.cached_actual_manhours).to eq(0)
    end

    it "excludes soft-deleted tasks from the rollup" do
      task = create(:task, project: project, unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3)
      task.destroy

      project.reload
      expect(project.cached_unassisted_estimate).to eq(0)
      expect(project.cached_ai_assisted_estimate).to eq(0)
      expect(project.cached_actual_manhours).to eq(0)
    end
  end

  describe "#organization" do
    it "returns the team's organization" do
      expect(project.organization).to eq(organization)
    end

    it "returns nil when the project has no team" do
      teamless = create(:project)
      expect(teamless.organization).to be_nil
    end
  end

  describe "#timezone" do
    it "returns the organization's timezone" do
      organization.update!(timezone: "America/New_York")
      expect(project.timezone).to eq("America/New_York")
    end

    it "falls back to the default timezone without an organization" do
      teamless = create(:project)
      expect(teamless.timezone).to eq("Australia/Brisbane")
    end
  end

  describe "#format_in_timezone" do
    it "returns nil for a nil datetime" do
      expect(project.format_in_timezone(nil)).to be_nil
    end

    it "formats the datetime in the organization's timezone" do
      organization.update!(timezone: "Australia/Brisbane")
      utc_time = Time.utc(2026, 1, 15, 0, 0) # 10:00 in Brisbane (UTC+10)
      expect(project.format_in_timezone(utc_time)).to eq("15 Jan 10:00")
    end
  end
end
