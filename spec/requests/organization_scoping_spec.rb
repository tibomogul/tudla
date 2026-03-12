require "rails_helper"

RSpec.describe "Organization Scoping", type: :request do
  let(:org_a) { create(:organization, name: "Org A") }
  let(:org_b) { create(:organization, name: "Org B") }
  let(:team_a) { create(:team, name: "Team A", organization: org_a) }
  let(:team_b) { create(:team, name: "Team B", organization: org_b) }
  let(:user) { create(:user) }

  before do
    UserPartyRole.create!(user: user, party: org_a, role: "admin")
    UserPartyRole.create!(user: user, party: org_b, role: "admin")
    sign_in(user)
  end

  # Parse the response into a Capybara document for scoped assertions
  def doc
    Capybara.string(response.body)
  end

  describe "GET /teams (index)" do
    it "only shows teams from the current organization" do
      team_a # create
      team_b # create

      # Default org is org_a (first alphabetically)
      get teams_url

      expect(doc).to have_text("Team A")
      expect(doc).not_to have_text("Team B")
    end

    it "shows teams from switched organization" do
      team_a # create
      team_b # create

      patch switch_organization_path(org_b)
      get teams_url

      expect(doc).to have_text("Team B")
      expect(doc).not_to have_text("Team A")
    end
  end

  describe "GET /projects (index)" do
    let!(:project_a) { create(:project, name: "Project Alpha", team: team_a) }
    let!(:project_b) { create(:project, name: "Project Beta", team: team_b) }

    it "only shows projects from the current organization" do
      get projects_url

      expect(doc).to have_text("Project Alpha")
      expect(doc).not_to have_text("Project Beta")
    end

    it "shows projects from switched organization" do
      patch switch_organization_path(org_b)
      get projects_url

      expect(doc).to have_text("Project Beta")
      expect(doc).not_to have_text("Project Alpha")
    end
  end

  describe "GET /scopes (index)" do
    let(:project_a) { create(:project, name: "Project Alpha", team: team_a) }
    let(:project_b) { create(:project, name: "Project Beta", team: team_b) }
    let!(:scope_a) { create(:scope, name: "Scope Alpha", project: project_a) }
    let!(:scope_b) { create(:scope, name: "Scope Beta", project: project_b) }

    it "only shows scopes from the current organization" do
      get scopes_url

      expect(doc).to have_text("Scope Alpha")
      expect(doc).not_to have_text("Scope Beta")
    end
  end

  describe "GET /tasks (index)" do
    let(:project_a) { create(:project, name: "Project Alpha", team: team_a) }
    let(:project_b) { create(:project, name: "Project Beta", team: team_b) }
    let(:scope_a) { create(:scope, project: project_a) }
    let(:scope_b) { create(:scope, project: project_b) }
    let!(:task_a) { create(:task, name: "Task Alpha", project: project_a, scope: scope_a) }
    let!(:task_b) { create(:task, name: "Task Beta", project: project_b, scope: scope_b) }

    it "only shows tasks from the current organization" do
      get tasks_url

      expect(doc).to have_text("Task Alpha")
      expect(doc).not_to have_text("Task Beta")
    end
  end

  describe "GET /dashboard" do
    let(:project_a) { create(:project, name: "Project Alpha", team: team_a) }
    let(:project_b) { create(:project, name: "Project Beta", team: team_b) }
    let(:scope_a) { create(:scope, project: project_a) }
    let(:scope_b) { create(:scope, project: project_b) }
    let!(:task_a) { create(:task, name: "Task Alpha", project: project_a, scope: scope_a, responsible_user: user, in_today: false) }
    let!(:task_b) { create(:task, name: "Task Beta", project: project_b, scope: scope_b, responsible_user: user, in_today: false) }

    it "only shows tasks from the current organization on the dashboard" do
      get user_root_path

      expect(doc).to have_text("Task Alpha")
      expect(doc).not_to have_text("Task Beta")
    end

    it "only shows projects from the current organization in the projects list" do
      get user_root_path

      expect(doc).to have_text("Project Alpha")
      expect(doc).not_to have_text("Project Beta")
    end
  end
end
