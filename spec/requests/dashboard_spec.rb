require 'rails_helper'

RSpec.describe "Dashboard", type: :request do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:user) { create(:user) }

  before do
    UserPartyRole.create!(user: user, party: team, role: "admin")
    sign_in(user)
  end

  # Parse the response into a Capybara document for scoped assertions
  def doc
    Capybara.string(response.body)
  end

  # Scope to the projects list turbo frame
  def projects_frame
    doc.find("turbo-frame#projects_list")
  end

  # Scope to the filter/stimulus wrapper
  def filter_wrapper
    doc.find('[data-controller="list-filter"]')
  end

  describe "GET /dashboard" do
    it "renders a successful response" do
      get user_root_url
      expect(response).to be_successful
    end

    context "with projects" do
      let!(:project_alpha) { create(:project, name: "Alpha Project", team: team) }
      let!(:project_beta) { create(:project, name: "Beta Project", team: team) }

      it "displays project names within the projects frame" do
        get user_root_url
        frame = projects_frame
        expect(frame).to have_text("Alpha Project")
        expect(frame).to have_text("Beta Project")
      end

      it "displays team names alongside projects" do
        get user_root_url
        expect(projects_frame).to have_text(team.name)
      end

      it "displays the project risk state" do
        get user_root_url
        expect(projects_frame).to have_text(project_alpha.risk_current_state.to_s.humanize)
      end

      it "displays the SQL-computed tasks_count per project" do
        create(:task, name: "Task A", project: project_alpha)
        create(:task, name: "Task B", project: project_alpha)
        create(:task, name: "Task C", project: project_beta)

        get user_root_url
        frame = projects_frame
        expect(frame).to have_text("2 tasks")
        expect(frame).to have_text("1 tasks")
      end

      it "excludes soft-deleted tasks from tasks_count" do
        create(:task, name: "Active Task", project: project_alpha)
        create(:task, name: "Deleted Task", project: project_alpha, deleted_at: 1.day.ago)

        get user_root_url
        # Should show 1, not 2 — soft-deleted task excluded by SQL subquery
        expect(projects_frame).to have_text("1 tasks")
        expect(projects_frame).not_to have_text("2 tasks")
      end
    end

    context "pagination" do
      before do
        12.times do |i|
          create(:project, name: "Project #{i.to_s.rjust(2, '0')}", team: team)
        end
      end

      it "paginates projects with a default limit of 10" do
        get user_root_url
        # Pagy default limit is 10; with 12 projects, page 1 shows 10
        links = projects_frame.all('a[data-turbo-frame="_top"]')
        expect(links.length).to eq(10)
      end

      it "renders pagination nav with a current-page indicator and page links" do
        get user_root_url
        nav = projects_frame
        # Current page rendered as a non-clickable element (span), not a link
        expect(nav).to have_css("span", text: "1")
        # Other pages rendered as clickable links
        expect(nav).to have_link("2")
      end

      it "navigates to page 2 and shows remaining projects" do
        get user_root_url, params: { page: 2 }
        links = projects_frame.all('a[data-turbo-frame="_top"]')
        expect(links.length).to eq(2)
      end
    end

    context "pagination with few items" do
      let!(:solo_project) { create(:project, name: "Solo Project", team: team) }

      it "does not render pagination nav when all items fit on one page" do
        get user_root_url
        # No pagination links should exist (no page number links beyond project links)
        expect(projects_frame).not_to have_link("2")
      end
    end

    context "filtering by project name" do
      let!(:matching_project) { create(:project, name: "Rails Dashboard", team: team) }
      let!(:other_project) { create(:project, name: "React Frontend", team: team) }

      it "filters projects by name (case-insensitive)" do
        get user_root_url, params: { project_name: "rails" }
        frame = projects_frame
        expect(frame).to have_text("Rails Dashboard")
        expect(frame).not_to have_text("React Frontend")
      end

      it "filters projects by partial name match" do
        get user_root_url, params: { project_name: "dash" }
        frame = projects_frame
        expect(frame).to have_text("Rails Dashboard")
        expect(frame).not_to have_text("React Frontend")
      end

      it "shows all projects when filter is empty" do
        get user_root_url, params: { project_name: "" }
        frame = projects_frame
        expect(frame).to have_text("Rails Dashboard")
        expect(frame).to have_text("React Frontend")
      end

      it "shows empty-state message when filter has no matches" do
        get user_root_url, params: { project_name: "zzz_nonexistent" }
        expect(projects_frame).to have_text("No projects found")
      end

      it "preserves the filter param in pagination links" do
        12.times { |i| create(:project, name: "Rails App #{i}", team: team) }

        get user_root_url, params: { project_name: "Rails" }
        # Pagination links within the frame should carry the filter param
        page_links = projects_frame.all("a[href*='page=']")
        expect(page_links).not_to be_empty
        page_links.each do |link|
          expect(link[:href]).to include("project_name=Rails")
        end
      end

      it "resets pagination when filtering" do
        15.times { |i| create(:project, name: "Filterable #{i}", team: team) }

        # Page 2 with no filter has results
        get user_root_url, params: { page: 2 }
        expect(response).to be_successful

        # Filter narrows to fewer than 10 results, page 1 should work
        get user_root_url, params: { project_name: "Rails" }
        expect(projects_frame).to have_text("Rails Dashboard")
      end
    end

    context "turbo frame requests" do
      let!(:project) { create(:project, name: "Turbo Project", team: team) }

      it "responds with the projects_list turbo frame content" do
        get user_root_url, headers: { "Turbo-Frame" => "projects_list" }
        expect(response).to be_successful
        expect(doc).to have_css("turbo-frame#projects_list", text: "Turbo Project")
      end

      it "does not render full dashboard layout for turbo frame requests" do
        get user_root_url, headers: { "Turbo-Frame" => "projects_list" }
        expect(doc).not_to have_text("My Day")
      end

      it "supports filtering within turbo frame requests" do
        create(:project, name: "Other Project", team: team)

        get user_root_url, params: { project_name: "Turbo" },
                           headers: { "Turbo-Frame" => "projects_list" }
        frame = doc.find("turbo-frame#projects_list")
        expect(frame).to have_text("Turbo Project")
        expect(frame).not_to have_text("Other Project")
      end

      it "supports pagination within turbo frame requests" do
        12.times { |i| create(:project, name: "Frame Project #{i}", team: team) }

        get user_root_url, params: { page: 2 },
                           headers: { "Turbo-Frame" => "projects_list" }
        expect(response).to be_successful
        expect(doc).to have_css("turbo-frame#projects_list")
      end
    end

    context "project links" do
      let!(:project) { create(:project, name: "Linked Project", team: team) }

      it "renders project links that break out of the turbo frame" do
        get user_root_url
        link = projects_frame.find("a", text: "Linked Project")
        expect(link[:"data-turbo-frame"]).to eq("_top")
      end
    end

    context "filter input" do
      it "wires the filter input to the list-filter stimulus controller" do
        get user_root_url
        wrapper = filter_wrapper
        expect(wrapper[:"data-list-filter-param-value"]).to eq("project_name")
        expect(wrapper[:"data-list-filter-frame-value"]).to eq("projects_list")

        input = wrapper.find("input")
        expect(input[:"data-action"]).to include("list-filter#filter")
      end

      it "preserves the current filter value in the input" do
        create(:project, name: "Preserved", team: team)
        get user_root_url, params: { project_name: "Preserved" }
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

        get user_root_url
        frame = projects_frame
        expect(frame).to have_text("Visible Project")
        expect(frame).not_to have_text("Invisible Project")
      end
    end
  end
end
