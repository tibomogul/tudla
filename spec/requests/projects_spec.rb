require "rails_helper"

RSpec.describe "/projects", type: :request do
  # An org-admin can do everything: see the org's projects, create them on any
  # team in the org, and update them. We grant the role on the Organization so
  # current_organization resolves to it and the access hierarchy flows down to
  # the team and its projects.
  let(:organization) { create(:organization) }
  let(:team)         { create(:team, organization: organization) }
  let(:user)         { create(:user) }

  let(:valid_attributes) { { name: "New Project", description: "Desc", team_id: team.id } }

  # Project has no model-level validations, so attributes alone can never make
  # save/update fail. The only way this controller renders new/edit with a 422
  # is the policy-injected team_id error from can_assign_to_team? — i.e. naming
  # a team the user may not assign to. That is the real "invalid params" path.
  let(:other_org)  { create(:organization) }
  let(:other_team) { create(:team, organization: other_org) }
  let(:invalid_attributes) { { name: "Sneaky Project", description: "Desc", team_id: other_team.id } }

  before do
    UserPartyRole.create!(user: user, party: organization, role: "admin")
    sign_in(user)
  end

  describe "GET /index" do
    it "renders a successful response listing accessible projects" do
      project = create(:project, team: team, name: "Visible Project")

      get projects_url

      expect(response).to be_successful
      expect(response.body).to include("Visible Project")
    end

    it "excludes soft-deleted projects from the list" do
      project = create(:project, team: team, name: "Archived Away")
      project.soft_delete

      get projects_url

      expect(response).to be_successful
      expect(response.body).not_to include("Archived Away")
    end

    it "redirects to sign-in when unauthenticated" do
      sign_out(user)

      get projects_url

      expect(response).not_to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      project = create(:project, team: team)

      get project_url(project)

      expect(response).to be_successful
    end

    # ProjectsController#show calls `authorize @project`, so a signed-in user with
    # no role in the project's org/team/project hierarchy is denied. Pundit raises
    # NotAuthorizedError, rescued by ApplicationController into a redirect to root.
    it "denies access to a user with no role in the project's hierarchy" do
      outsider = create(:user)
      sign_out(user)
      sign_in(outsider)
      project = create(:project, team: team)

      get project_url(project)

      expect(response).to redirect_to(root_path)
    end

    it "links back to the originating pitch when one is attached" do
      pitch = create(:pitch, user: user, organization: organization, title: "Origin Pitch")
      project = create(:project, team: team, pitch: pitch)

      get project_url(project)

      expect(response.body).to include("Shaped from pitch")
      expect(response.body).to include(pitch_path(pitch))
      expect(response.body).to include("Origin Pitch")
    end

    it "hides the pitch link from a project-only member who cannot see the pitch" do
      author = create(:user)
      UserPartyRole.create!(user: author, party: organization, role: "member")
      pitch = create(:pitch, user: author, organization: organization, title: "Hidden Pitch")
      project = create(:project, team: team, pitch: pitch)

      viewer = create(:user)
      UserPartyRole.create!(user: viewer, party: project, role: "member")
      sign_out(user)
      sign_in(viewer)

      get project_url(project)

      expect(response).to be_successful
      expect(response.body).not_to include("Shaped from pitch")
      expect(response.body).not_to include("Hidden Pitch")
    end
  end

  describe "GET /new" do
    it "renders a successful response for a user who can create projects" do
      get new_project_url
      expect(response).to be_successful
    end

    it "denies a user with no admin role anywhere" do
      plain_member = create(:user)
      UserPartyRole.create!(user: plain_member, party: organization, role: "member")
      sign_out(user)
      sign_in(plain_member)

      get new_project_url

      expect(response).not_to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      project = create(:project, team: team)

      get edit_project_url(project)

      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Project" do
        expect {
          post projects_url, params: { project: valid_attributes }
        }.to change(Project, :count).by(1)
      end

      it "assigns the submitted attributes and team" do
        post projects_url, params: { project: valid_attributes }

        project = Project.last
        expect(project.name).to eq("New Project")
        expect(project.team).to eq(team)
      end

      it "redirects to the created project" do
        post projects_url, params: { project: valid_attributes }
        expect(response).to redirect_to(project_url(Project.last))
      end
    end

    context "with a team the user may not assign to" do
      # authorize @project runs first and fails (create? checks admin on the
      # target team/org), so this is a Pundit authorization redirect, not the
      # inline 422 render. No project is created either way.
      it "does not create a new Project" do
        expect {
          post projects_url, params: { project: invalid_attributes }
        }.to change(Project, :count).by(0)
      end

      it "is not authorized" do
        post projects_url, params: { project: invalid_attributes }
        expect(response).not_to be_successful
        expect(response).to have_http_status(:found)
      end
    end

    context "when the user has no create authorization at all" do
      it "is forbidden and creates nothing" do
        plain_member = create(:user)
        UserPartyRole.create!(user: plain_member, party: organization, role: "member")
        sign_out(user)
        sign_in(plain_member)

        expect {
          post projects_url, params: { project: valid_attributes }
        }.not_to change(Project, :count)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) { { name: "Updated Name", description: "Updated Desc" } }

      it "updates the requested project" do
        project = create(:project, team: team, name: "Old Name")

        patch project_url(project), params: { project: new_attributes }
        project.reload

        expect(project.name).to eq("Updated Name")
        expect(project.description).to eq("Updated Desc")
      end

      it "redirects to the project" do
        project = create(:project, team: team)

        patch project_url(project), params: { project: new_attributes }
        project.reload

        expect(response).to redirect_to(project_url(project))
      end
    end

    context "with invalid parameters (reassigning to a forbidden team)" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        project = create(:project, team: team)

        patch project_url(project), params: { project: invalid_attributes }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not change the project" do
        project = create(:project, team: team, name: "Keep Me")

        patch project_url(project), params: { project: invalid_attributes }

        expect(project.reload.name).to eq("Keep Me")
        expect(project.reload.team).to eq(team)
      end
    end
  end

  describe "DELETE /destroy" do
    # The policy's destroy? returns false for everyone, so the controller's
    # authorize @project raises Pundit::NotAuthorizedError, which is rescued
    # into a forbidden/redirect response. The project must survive.
    it "is not authorized and leaves the project intact" do
      project = create(:project, team: team)

      delete project_url(project)

      expect(response).not_to be_successful
      expect(Project.active).to include(project)
      expect(project.reload.deleted_at).to be_nil
    end
  end
end
