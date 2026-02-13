require 'rails_helper'

RSpec.describe "Projects Index", type: :request do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:user) { create(:user) }

  before do
    UserPartyRole.create!(user: user, party: team, role: "admin")
    sign_in(user)
  end

  def doc
    Capybara.string(response.body)
  end

  def projects_frame
    doc.find("turbo-frame#projects_index_list")
  end

  def filter_wrapper
    doc.find('[data-controller="list-filter"]')
  end

  describe "GET /projects" do
    it "renders a successful response" do
      get projects_url
      expect(response).to be_successful
    end

    context "with projects" do
      let!(:project_alpha) { create(:project, name: "Alpha Project", team: team) }
      let!(:project_beta) { create(:project, name: "Beta Project", team: team) }

      it "displays project names within the projects frame" do
        get projects_url
        frame = projects_frame
        expect(frame).to have_text("Alpha Project")
        expect(frame).to have_text("Beta Project")
      end

      it "displays team names alongside projects" do
        get projects_url
        expect(projects_frame).to have_text(team.name)
      end

      it "displays the project risk state" do
        get projects_url
        expect(projects_frame).to have_text(project_alpha.risk_current_state.to_s.humanize)
      end

      it "displays the SQL-computed tasks_count per project" do
        create(:task, name: "Task A", project: project_alpha)
        create(:task, name: "Task B", project: project_alpha)

        get projects_url
        expect(projects_frame).to have_text("2 tasks")
      end

      it "excludes soft-deleted tasks from tasks_count" do
        create(:task, name: "Active Task", project: project_alpha)
        create(:task, name: "Deleted Task", project: project_alpha, deleted_at: 1.day.ago)

        get projects_url
        expect(projects_frame).to have_text("1 task")
        expect(projects_frame).not_to have_text("2 tasks")
      end

      it "displays the SQL-computed scopes_count per project" do
        create(:scope, name: "Scope A", project: project_alpha)
        create(:scope, name: "Scope B", project: project_alpha)

        get projects_url
        expect(projects_frame).to have_text("2 scopes")
      end

      it "excludes soft-deleted scopes from scopes_count" do
        create(:scope, name: "Active Scope", project: project_alpha)
        create(:scope, name: "Deleted Scope", project: project_alpha, deleted_at: 1.day.ago)

        get projects_url
        expect(projects_frame).to have_text("1 scope")
        expect(projects_frame).not_to have_text("2 scopes")
      end
    end

    context "pagination" do
      before do
        22.times do |i|
          create(:project, name: "Project #{i.to_s.rjust(2, '0')}", team: team)
        end
      end

      it "paginates projects with a limit of 20" do
        get projects_url
        links = projects_frame.all('a[data-turbo-frame="_top"]')
        expect(links.count { |l| l.text.match?(/Project \d{2}/) }).to eq(20)
      end

      it "renders pagination nav with a current-page indicator and page links" do
        get projects_url
        nav = projects_frame
        expect(nav).to have_css("span", text: "1")
        expect(nav).to have_link("2")
      end

      it "navigates to page 2 and shows remaining projects" do
        get projects_url, params: { page: 2 }
        links = projects_frame.all('a[data-turbo-frame="_top"]')
        expect(links.count { |l| l.text.match?(/Project \d{2}/) }).to eq(2)
      end
    end

    context "pagination with few items" do
      let!(:solo_project) { create(:project, name: "Solo Project", team: team) }

      it "does not render pagination nav when all items fit on one page" do
        get projects_url
        expect(projects_frame).not_to have_link("2")
      end
    end

    context "filtering by project name" do
      let!(:matching_project) { create(:project, name: "Rails Dashboard", team: team) }
      let!(:other_project) { create(:project, name: "React Frontend", team: team) }

      it "filters projects by name (case-insensitive)" do
        get projects_url, params: { project_name: "rails" }
        frame = projects_frame
        expect(frame).to have_text("Rails Dashboard")
        expect(frame).not_to have_text("React Frontend")
      end

      it "filters projects by partial name match" do
        get projects_url, params: { project_name: "dash" }
        frame = projects_frame
        expect(frame).to have_text("Rails Dashboard")
        expect(frame).not_to have_text("React Frontend")
      end

      it "shows all projects when filter is empty" do
        get projects_url, params: { project_name: "" }
        frame = projects_frame
        expect(frame).to have_text("Rails Dashboard")
        expect(frame).to have_text("React Frontend")
      end

      it "shows empty-state message when filter has no matches" do
        get projects_url, params: { project_name: "zzz_nonexistent" }
        expect(projects_frame).to have_text("No projects found")
      end

      it "preserves the filter param in pagination links" do
        22.times { |i| create(:project, name: "Rails App #{i}", team: team) }

        get projects_url, params: { project_name: "Rails" }
        page_links = projects_frame.all("a[href*='page=']")
        expect(page_links).not_to be_empty
        page_links.each do |link|
          expect(link[:href]).to include("project_name=Rails")
        end
      end
    end

    context "turbo frame requests" do
      let!(:project) { create(:project, name: "Turbo Project", team: team) }

      it "responds with the projects_index_list turbo frame content" do
        get projects_url, headers: { "Turbo-Frame" => "projects_index_list" }
        expect(response).to be_successful
        expect(doc).to have_css("turbo-frame#projects_index_list", text: "Turbo Project")
      end

      it "does not render full page layout for turbo frame requests" do
        get projects_url, headers: { "Turbo-Frame" => "projects_index_list" }
        expect(doc).not_to have_css("h1", text: "Projects")
      end

      it "supports filtering within turbo frame requests" do
        create(:project, name: "Other Project", team: team)

        get projects_url, params: { project_name: "Turbo" },
                          headers: { "Turbo-Frame" => "projects_index_list" }
        frame = doc.find("turbo-frame#projects_index_list")
        expect(frame).to have_text("Turbo Project")
        expect(frame).not_to have_text("Other Project")
      end
    end

    context "project links" do
      let!(:project) { create(:project, name: "Linked Project", team: team) }

      it "renders project name links that break out of the turbo frame" do
        get projects_url
        link = projects_frame.find("a", text: "Linked Project")
        expect(link[:"data-turbo-frame"]).to eq("_top")
      end
    end

    context "filter input" do
      it "wires the filter input to the list-filter stimulus controller" do
        get projects_url
        wrapper = filter_wrapper
        expect(wrapper[:"data-list-filter-param-value"]).to eq("project_name")
        expect(wrapper[:"data-list-filter-frame-value"]).to eq("projects_index_list")

        input = wrapper.find("input")
        expect(input[:"data-action"]).to include("list-filter#filter")
      end

      it "preserves the current filter value in the input" do
        create(:project, name: "Preserved", team: team)
        get projects_url, params: { project_name: "Preserved" }
        input = filter_wrapper.find("input")
        expect(input.value).to eq("Preserved")
      end
    end

    context "policy scoping" do
      it "only shows projects visible to the current user" do
        _visible_project = create(:project, name: "Visible Project", team: team)

        other_org = create(:organization, name: "Other Org")
        other_team = create(:team, name: "Other Team", organization: other_org)
        _invisible_project = create(:project, name: "Invisible Project", team: other_team)

        get projects_url
        frame = projects_frame
        expect(frame).to have_text("Visible Project")
        expect(frame).not_to have_text("Invisible Project")
      end
    end
  end
end
