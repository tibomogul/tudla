require "rails_helper"

RSpec.describe "/scopes", type: :request do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:user) { create(:user) }
  let(:project) { create(:project, team: team) }

  before do
    UserPartyRole.create!(user: user, party: team, role: "admin")
    sign_in(user)
  end

  # Parse the response into a Capybara document for scoped assertions
  def doc
    Capybara.string(response.body)
  end

  describe "GET /scopes/:id (show)" do
    let(:scope_record) { create(:scope, name: "Test Scope", project: project) }

    context "with active and soft-deleted tasks" do
      let!(:active_task) { create(:task, name: "Active Task", scope: scope_record, project: project) }
      let!(:deleted_task) { create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago) }

      it "renders a successful response" do
        get scope_url(scope_record)
        expect(response).to be_successful
      end

      it "displays only active tasks in the task list" do
        get scope_url(scope_record)

        expect(doc).to have_text("Active Task")
        expect(doc).not_to have_text("Deleted Task")
      end

      it "excludes soft-deleted tasks from the task count" do
        get scope_url(scope_record)

        # The task list should only show 1 task, not 2
        task_list = doc.find("##{ActionView::RecordIdentifier.dom_id(scope_record, :task_list)}")
        task_items = task_list.all("li[id^='task_']")
        expect(task_items.count).to eq(1)
      end
    end

    context "with only soft-deleted tasks" do
      let!(:deleted_task_1) { create(:task, name: "Deleted Task 1", scope: scope_record, project: project, deleted_at: 1.day.ago) }
      let!(:deleted_task_2) { create(:task, name: "Deleted Task 2", scope: scope_record, project: project, deleted_at: 2.days.ago) }

      it "shows empty task list when all tasks are soft-deleted" do
        get scope_url(scope_record)

        expect(doc).not_to have_text("Deleted Task 1")
        expect(doc).not_to have_text("Deleted Task 2")
      end
    end
  end

  describe "GET /scopes (index)" do
    context "task count display" do
      let!(:scope_record) { create(:scope, name: "Test Scope", project: project) }

      it "excludes soft-deleted tasks from task count" do
        create(:task, name: "Active Task", scope: scope_record, project: project)
        create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago)

        get scopes_url

        # Should show "1 task", not "2 tasks"
        expect(doc).to have_text("1 task")
        expect(doc).not_to have_text("2 tasks")
      end

      it "shows correct task count when all tasks are soft-deleted" do
        create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago)

        get scopes_url

        # Task count section should not appear when count is 0
        expect(doc).not_to have_text("1 task")
      end
    end
  end

  describe "PATCH /scopes/:id/reorder_tasks" do
    let(:scope_record) { create(:scope, name: "Test Scope", project: project) }
    let!(:task_1) { create(:task, name: "Task 1", scope: scope_record, project: project, scope_position: 0) }
    let!(:task_2) { create(:task, name: "Task 2", scope: scope_record, project: project, scope_position: 1) }
    let!(:deleted_task) { create(:task, name: "Deleted Task", scope: scope_record, project: project, deleted_at: 1.day.ago) }

    it "reorders only active tasks" do
      patch reorder_tasks_scope_url(scope_record), params: { ids: [ task_2.id, task_1.id ] }

      expect(response).to be_successful
      expect(task_2.reload.scope_position).to eq(0)
      expect(task_1.reload.scope_position).to eq(1)
    end

    it "ignores soft-deleted task IDs in reorder request" do
      # Even if deleted task ID is passed, it should be ignored
      # The deleted task ID is skipped, so task_2 gets position 1 and task_1 gets position 2
      patch reorder_tasks_scope_url(scope_record), params: { ids: [deleted_task.id, task_2.id, task_1.id] }

      expect(response).to be_successful
      # Deleted task is skipped (not found in policy_scope), so positions are:
      # - deleted_task.id at index 0 -> skipped (not found)
      # - task_2.id at index 1 -> position 1
      # - task_1.id at index 2 -> position 2
      expect(task_2.reload.scope_position).to eq(1)
      expect(task_1.reload.scope_position).to eq(2)
    end
  end
end
