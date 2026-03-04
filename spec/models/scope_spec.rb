require "rails_helper"

RSpec.describe Scope, type: :model do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:scope_record) { create(:scope, project: project) }

  describe "#percent_done" do
    context "with active and soft-deleted tasks" do
      it "excludes soft-deleted tasks from total count" do
        create(:task, name: "Active Task", scope: scope_record, project: project)
        create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago)

        # Total should be 1 (only active), not 2
        expect(scope_record.tasks.active.count).to eq(1)
      end

      it "returns 0 when all tasks are soft-deleted" do
        create(:task, name: "Deleted Task 1", scope: scope_record, project: project, deleted_at: 1.day.ago)
        create(:task, name: "Deleted Task 2", scope: scope_record, project: project, deleted_at: 1.day.ago)

        expect(scope_record.percent_done).to eq(0)
      end

      it "calculates percent_done using only active tasks" do
        # Create a user to assign as responsible_user (required for state transitions)
        user = create(:user, email: "task_user@example.com", confirmation_token: "token_task_user")

        # Create an active task in "done" state with required fields for transition
        done_task = create(:task, name: "Done Task", scope: scope_record, project: project,
                                  responsible_user: user, unassisted_estimate: 4, ai_assisted_estimate: 2)
        done_task.state_machine.transition_to!(:in_progress)
        done_task.state_machine.transition_to!(:in_review)
        done_task.state_machine.transition_to!(:done)

        # Create an active task in "new" state
        create(:task, name: "New Task", scope: scope_record, project: project)

        # Create a soft-deleted task (should be excluded from calculation)
        create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago)

        # Should be 50% (1 done out of 2 active), not 33% (1 done out of 3 total)
        expect(scope_record.percent_done).to eq(50)
      end
    end

    context "with no tasks" do
      it "returns 0 when scope has no tasks" do
        expect(scope_record.percent_done).to eq(0)
      end
    end
  end

  describe "tasks association" do
    it "includes soft-deleted tasks in unscoped association" do
      create(:task, name: "Active Task", scope: scope_record, project: project)
      create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago)

      # Raw association includes all tasks
      expect(scope_record.tasks.count).to eq(2)
    end

    it "excludes soft-deleted tasks when using .active scope" do
      create(:task, name: "Active Task", scope: scope_record, project: project)
      create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago)

      # Active scope filters out soft-deleted
      expect(scope_record.tasks.active.count).to eq(1)
      expect(scope_record.tasks.active.first.name).to eq("Active Task")
    end
  end
end
