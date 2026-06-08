# Example: request spec. Prefer these over controller specs. Devise
# IntegrationHelpers are mixed in for type: :request, so sign_in(user) works.
#
# WHY this shape: mirrors spec/requests/* and the authorization guidance in
# references/authorization.md. Replace the resource and adjust authorization.

require "rails_helper"

RSpec.describe "/projects", type: :request do
  let(:organization) { create(:organization) }
  let(:team)         { create(:team, organization: organization) }
  let(:project)      { create(:project, team: team) }

  let(:admin) { create(:user) }

  before do
    UserPartyRole.create!(user: admin, party: organization, role: "admin")
  end

  describe "GET /projects" do
    context "when unauthenticated" do
      it "redirects to sign-in" do
        get projects_url
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as an org admin" do
      before { sign_in(admin) }

      it "renders successfully" do
        project # materialize
        get projects_url
        expect(response).to be_successful
      end
    end
  end

  describe "GET /projects/:id" do
    before { sign_in(admin) }

    it "renders a project the user can access" do
      get project_url(project)
      expect(response).to be_successful
    end

    it "does not expose a soft-deleted project" do
      project.soft_delete
      # WHY: controllers must query .active — a deleted record should 404 or
      # redirect, never render. Assert the real behaviour of this controller.
      get project_url(project)
      expect(response).not_to be_successful
    end
  end

  describe "PATCH /projects/:id with a Turbo Stream form" do
    before { sign_in(admin) }

    it "honours update_context when streaming the response" do
      # WHY: Turbo Stream forms pass a hidden update_context field that selects
      # the partial to re-render. Include it so the correct branch is exercised.
      patch project_url(project),
            params: { project: { name: "Renamed" }, update_context: "details" },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(project.reload.name).to eq("Renamed")
    end
  end
end
