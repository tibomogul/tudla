require "rails_helper"

RSpec.describe ProjectLifecycleStateMachine, type: :model do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }

  describe "transitions" do
    it "starts in active" do
      expect(project.current_lifecycle_state).to eq("active")
      expect(project).to be_active
    end

    it "allows active -> done" do
      project.lifecycle_state_machine.transition_to!(:done)
      expect(project.reload.lifecycle_state).to eq("done")
      expect(project).to be_done
      expect(project.done_at).to be_present
      expect(project).to be_read_only
    end

    it "allows active -> archived" do
      project.lifecycle_state_machine.transition_to!(:archived)
      expect(project.reload.lifecycle_state).to eq("archived")
      expect(project.archived_at).to be_present
    end

    it "allows done -> archived" do
      project.lifecycle_state_machine.transition_to!(:done)
      project.lifecycle_state_machine.transition_to!(:archived)
      expect(project.reload).to be_archived
    end

    it "allows done -> active (reopen)" do
      project.lifecycle_state_machine.transition_to!(:done)
      project.lifecycle_state_machine.transition_to!(:active)
      expect(project.reload).to be_active
      expect(project).not_to be_read_only
    end

    it "allows archived -> active (reopen)" do
      project.lifecycle_state_machine.transition_to!(:archived)
      project.lifecycle_state_machine.transition_to!(:active)
      expect(project.reload).to be_active
    end

    it "forbids archived -> done (must reopen first)" do
      project.lifecycle_state_machine.transition_to!(:archived)
      expect {
        project.lifecycle_state_machine.transition_to!(:done)
      }.to raise_error(Statesman::TransitionFailedError)
    end
  end

  describe "propagation to children" do
    let!(:scope) { create(:scope, project: project) }
    let!(:task1) { create(:task, project: project, scope: scope) }
    let!(:task2) { create(:task, project: project) }

    it "bulk-updates scopes and tasks on transition to done" do
      project.lifecycle_state_machine.transition_to!(:done)
      expect(scope.reload.project_lifecycle_state).to eq("done")
      expect(task1.reload.project_lifecycle_state).to eq("done")
      expect(task2.reload.project_lifecycle_state).to eq("done")
      expect(scope).to be_read_only
      expect(task1).to be_read_only
    end

    it "clears read-only on reopen" do
      project.lifecycle_state_machine.transition_to!(:archived)
      project.lifecycle_state_machine.transition_to!(:active)
      expect(scope.reload.project_lifecycle_state).to eq("active")
      expect(task1.reload.project_lifecycle_state).to eq("active")
      expect(scope).not_to be_read_only
    end

    it "uses a single UPDATE per child table (no N+1)" do
      # Add more children to make the count meaningful
      3.times { create(:task, project: project) }
      queries = []
      callback = ->(_, _, _, _, payload) { queries << payload[:sql] if payload[:sql] =~ /UPDATE/i }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        project.lifecycle_state_machine.transition_to!(:done)
      end
      scope_updates = queries.count { |q| q =~ /UPDATE "scopes".*project_lifecycle_state/m }
      task_updates  = queries.count { |q| q =~ /UPDATE "tasks".*project_lifecycle_state/m }
      expect(scope_updates).to eq(1)
      expect(task_updates).to eq(1)
    end
  end

  describe "new children inherit project lifecycle state" do
    it "new scope inherits archived state" do
      project.lifecycle_state_machine.transition_to!(:archived)
      new_scope = create(:scope, project: project)
      expect(new_scope.project_lifecycle_state).to eq("archived")
      expect(new_scope).to be_read_only
    end

    it "new task inherits archived state" do
      project.lifecycle_state_machine.transition_to!(:archived)
      new_task = create(:task, project: project)
      expect(new_task.project_lifecycle_state).to eq("archived")
    end
  end
end
