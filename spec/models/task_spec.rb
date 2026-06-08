require "rails_helper"

RSpec.describe Task, type: :model do
  let(:organization) { create(:organization) }
  let(:team)         { create(:team, organization: organization) }
  let(:project)      { create(:project, team: team) }
  let(:scope)        { create(:scope, project: project) }
  let(:user)         { create(:user) }

  describe "#organization" do
    it "walks project -> team -> organization" do
      task = create(:task, project: project)
      expect(task.organization).to eq(organization)
    end

    it "is nil when the task has no project" do
      expect(create(:task).organization).to be_nil
    end
  end

  describe "#timezone" do
    it "returns the organization's timezone" do
      org  = create(:organization, timezone: "America/New_York")
      team = create(:team, organization: org)
      task = create(:task, project: create(:project, team: team))
      expect(task.timezone).to eq("America/New_York")
    end

    it "falls back to Australia/Brisbane when there is no organization" do
      expect(create(:task).timezone).to eq("Australia/Brisbane")
    end
  end

  describe "#format_in_timezone" do
    it "renders a UTC instant in the organization's timezone" do
      task = create(:task, project: project) # org defaults to Australia/Brisbane (UTC+10)
      # 23:00 UTC on the 15th is 09:00 on the 16th in Brisbane
      expect(task.format_in_timezone(Time.utc(2026, 1, 15, 23, 0))).to eq("16 Jan 09:00")
    end

    it "returns nil for a nil datetime" do
      expect(create(:task).format_in_timezone(nil)).to be_nil
    end
  end

  describe "soft delete" do
    let!(:task) { create(:task, project: project) }

    it "excludes soft-deleted tasks from .active" do
      task.soft_delete
      expect(Task.active).not_to include(task)
      expect(task.deleted_at).to be_present
    end

    it "restores a soft-deleted task back into .active" do
      task.soft_delete
      task.restore
      expect(Task.active).to include(task)
      expect(task.deleted_at).to be_nil
    end
  end

  describe "state machine" do
    it "starts in the new state" do
      expect(create(:task, project: project).current_state).to eq("new")
    end

    it "raises on a forbidden edge (new -> done)" do
      task = create(:task, project: project)
      expect { task.state_machine.transition_to!(:done) }
        .to raise_error(Statesman::TransitionFailedError)
    end

    context "guard on :in_progress" do
      it "allows new -> in_progress when responsible_user and both estimates are present" do
        task = create(:task, project: project, responsible_user: user,
                             unassisted_estimate: 5, ai_assisted_estimate: 3)
        task.state_machine.transition_to!(:in_progress, user_id: user.id)
        expect(task.reload.current_state).to eq("in_progress")
      end

      it "blocks the transition when an estimate is missing" do
        task = create(:task, project: project, responsible_user: user,
                             unassisted_estimate: nil, ai_assisted_estimate: 3)
        expect(task.state_machine.can_transition_to?(:in_progress)).to be false
        expect { task.state_machine.transition_to!(:in_progress) }
          .to raise_error(Statesman::GuardFailedError)
      end

      it "blocks the transition when there is no responsible_user" do
        task = create(:task, project: project, responsible_user: nil,
                             unassisted_estimate: 5, ai_assisted_estimate: 3)
        expect(task.state_machine.can_transition_to?(:in_progress)).to be false
      end
    end

    it "persists the user_id in the transition metadata" do
      task = create(:task, project: project, responsible_user: user,
                           unassisted_estimate: 5, ai_assisted_estimate: 3)
      task.state_machine.transition_to!(:in_progress, user_id: user.id)
      expect(task.task_transitions.order(:sort_key).last.metadata["user_id"]).to eq(user.id)
    end
  end

  describe "estimate rollup (EstimateCacheable)" do
    it "updates scope and project cached estimates on create" do
      create(:task, scope: scope, project: project,
                    unassisted_estimate: 10, ai_assisted_estimate: 5, actual_manhours: 3)
      scope.reload
      project.reload
      expect(scope.cached_unassisted_estimate).to eq(10)
      expect(project.cached_unassisted_estimate).to eq(10)
    end

    it "decrements parent caches when a task is destroyed (soft delete + recalc)" do
      # NOTE: bare #soft_delete only flips deleted_at via update_column and skips
      # callbacks; EstimateCacheable overrides #destroy/#restore to also recalc.
      task = create(:task, scope: scope, project: project, unassisted_estimate: 10)
      task.destroy
      scope.reload
      project.reload
      expect(scope.cached_unassisted_estimate).to eq(0)
      expect(project.cached_unassisted_estimate).to eq(0)
    end

    it "treats nil estimates as 0" do
      create(:task, scope: scope, project: project, unassisted_estimate: nil)
      expect(scope.reload.cached_unassisted_estimate).to eq(0)
    end
  end

  describe "#read_only?" do
    it "is false for a task under an active project" do
      expect(create(:task, project: project).read_only?).to be false
    end

    it "becomes true after the project leaves the active lifecycle state" do
      task = create(:task, project: project)
      project.lifecycle_state_machine.transition_to!(:archived)
      expect(task.reload.read_only?).to be true
    end
  end

  describe "#assignable_users" do
    it "includes the responsible user, the project's team members, and direct project members" do
      responsible   = create(:user)
      team_member   = create(:user)
      direct_member = create(:user)
      UserPartyRole.create!(user: team_member, party: team, role: "member")
      UserPartyRole.create!(user: direct_member, party: project, role: "member")

      task = create(:task, project: project, responsible_user: responsible)

      expect(task.assignable_users).to include(responsible, team_member, direct_member)
    end

    it "de-duplicates a user who is both responsible and a team member" do
      both = create(:user)
      UserPartyRole.create!(user: both, party: team, role: "member")
      task = create(:task, project: project, responsible_user: both)

      expect(task.assignable_users.count(both)).to eq(1)
    end
  end
end
