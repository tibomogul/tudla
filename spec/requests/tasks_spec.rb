require "rails_helper"

RSpec.describe "/tasks", type: :request do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:scope_record) { create(:scope, project: project) }
  let(:user) { create(:user) }

  # An organization-level role is required so that `current_organization`
  # resolves — the index action filters tasks by
  # `current_organization_project_ids`, which is empty when there is no
  # current organization. It also grants access to the team's projects.
  before do
    UserPartyRole.create!(user: user, party: organization, role: "admin")
    sign_in(user)
  end

  def doc
    Capybara.string(response.body)
  end

  let(:valid_attributes) do
    {
      name: "Write the request spec",
      description: "Cover every CRUD action",
      project_id: project.id,
      scope_id: scope_record.id,
      responsible_user_id: user.id,
      unassisted_estimate: 8,
      ai_assisted_estimate: 4
    }
  end

  # NOTE: the Task model declares no validations, so `@task.save` / `@task.update`
  # never return false for attribute-level bad input. The controller's
  # "unprocessable_entity" branches are therefore only reachable via a database
  # constraint error (which raises rather than returning false). There is no
  # meaningful "invalid params re-renders the form" path to assert for this
  # model, so those scaffold examples are intentionally omitted.

  describe "GET /index" do
    it "renders a successful response" do
      get tasks_url
      expect(response).to be_successful
    end

    it "displays tasks belonging to the current organization's projects" do
      create(:task, name: "Visible Task", project: project, scope: scope_record, responsible_user: user)
      get tasks_url
      expect(doc).to have_text("Visible Task")
    end

    it "does not display soft-deleted tasks" do
      create(:task, name: "Active Task", project: project, scope: scope_record, responsible_user: user)
      create(:task, name: "Deleted Task", project: project, scope: scope_record, responsible_user: user, deleted_at: 1.day.ago)
      get tasks_url
      expect(doc).to have_text("Active Task")
      expect(doc).not_to have_text("Deleted Task")
    end

    it "does not display tasks from another organization's projects" do
      other_org = create(:organization)
      other_team = create(:team, organization: other_org)
      other_project = create(:project, team: other_team)
      other_scope = create(:scope, project: other_project)
      create(:task, name: "Foreign Task", project: other_project, scope: other_scope)
      get tasks_url
      expect(doc).not_to have_text("Foreign Task")
    end
  end

  describe "GET /show" do
    let(:task) { create(:task, name: "Showable Task", project: project, scope: scope_record, responsible_user: user) }

    it "renders a successful response" do
      get task_url(task)
      expect(response).to be_successful
      expect(doc).to have_text("Showable Task")
    end

    it "denies access to a task the user has no role over" do
      other_org = create(:organization)
      other_team = create(:team, organization: other_org)
      other_project = create(:project, team: other_team)
      other_scope = create(:scope, project: other_project)
      foreign_task = create(:task, project: other_project, scope: other_scope)

      # set_task uses policy_scope(Task).find, which excludes inaccessible
      # records and raises RecordNotFound. With show_exceptions = :rescuable in
      # test, Rails renders that as a 404 response rather than propagating.
      get task_url(foreign_task)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_task_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    let(:task) { create(:task, project: project, scope: scope_record, responsible_user: user) }

    it "renders a successful response" do
      get edit_task_url(task)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Task" do
        expect {
          post tasks_url, params: { task: valid_attributes }
        }.to change(Task.active, :count).by(1)
      end

      it "persists the submitted attributes" do
        post tasks_url, params: { task: valid_attributes }
        task = Task.active.order(:created_at).last
        expect(task.name).to eq("Write the request spec")
        expect(task.project).to eq(project)
        expect(task.scope).to eq(scope_record)
        expect(task.responsible_user).to eq(user)
        expect(task.unassisted_estimate).to eq(8)
      end

      it "redirects to the created task" do
        post tasks_url, params: { task: valid_attributes }
        expect(response).to redirect_to(task_url(Task.active.order(:created_at).last))
      end

      it "rolls the new estimate into the parent scope cache" do
        post tasks_url, params: { task: valid_attributes }
        expect(scope_record.reload.cached_unassisted_estimate).to eq(8)
        expect(scope_record.cached_ai_assisted_estimate).to eq(4)
      end
    end

    context "when the user has no access to the target project" do
      let(:outsider) { create(:user) }

      before do
        sign_out(user)
        sign_in(outsider)
      end

      it "does not create a task and is not authorized" do
        # create? denies a user with no role on the task's org/team/project,
        # so Pundit raises and ApplicationController redirects with an alert.
        expect {
          post tasks_url, params: { task: valid_attributes }
        }.not_to change(Task.active, :count)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /update" do
    let!(:task) do
      create(:task, name: "Before", project: project, scope: scope_record,
                    responsible_user: user, unassisted_estimate: 2)
    end

    context "with valid parameters" do
      let(:new_attributes) { { name: "After", unassisted_estimate: 10 } }

      it "updates the requested task" do
        patch task_url(task), params: { task: new_attributes }
        task.reload
        expect(task.name).to eq("After")
        expect(task.unassisted_estimate).to eq(10)
      end

      it "redirects to the task" do
        patch task_url(task), params: { task: new_attributes }
        expect(response).to redirect_to(task_url(task))
      end

      it "recomputes the parent scope estimate cache" do
        patch task_url(task), params: { task: new_attributes }
        expect(scope_record.reload.cached_unassisted_estimate).to eq(10)
      end
    end

    context "when the user is a plain org member who is not the owner" do
      let(:member) { create(:user) }

      before do
        # update? allows org *admins* but not plain org *members* (unless they
        # are the owner or a team/project member). This member is none of those,
        # so the update must be refused.
        UserPartyRole.create!(user: member, party: organization, role: "member")
        sign_out(user)
        sign_in(member)
      end

      it "is not authorized and leaves the task unchanged" do
        patch task_url(task), params: { task: { name: "Touched" } }
        expect(task.reload.name).to eq("Before")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /destroy" do
    let!(:task) do
      create(:task, project: project, scope: scope_record,
                    responsible_user: user, unassisted_estimate: 5)
    end

    it "soft-deletes the requested task" do
      expect {
        delete task_url(task)
      }.to change(Task.active, :count).by(-1)
      expect(task.reload.deleted_at).to be_present
      expect(Task.active).not_to include(task)
    end

    it "redirects to the tasks list" do
      delete task_url(task)
      expect(response).to redirect_to(tasks_url)
    end

    it "removes the estimate from the parent scope cache" do
      delete task_url(task)
      expect(scope_record.reload.cached_unassisted_estimate).to eq(0)
    end

    context "when the user is not the owner" do
      let(:other_owner) { create(:user) }
      let!(:task) do
        create(:task, project: project, scope: scope_record,
                      responsible_user: other_owner, unassisted_estimate: 5)
      end

      it "is forbidden and does not delete the task" do
        # destroy? requires is_owner?; an org admin who is not the owner is denied.
        expect {
          delete task_url(task)
        }.not_to change(Task.active, :count)
        expect(response).to redirect_to(root_path)
        expect(task.reload.deleted_at).to be_nil
      end
    end
  end
end
