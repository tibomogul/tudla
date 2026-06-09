require "rails_helper"

# Request specs for TeamsController.
#
# Behaviour notes that shape these examples (see TeamsController +
# ApplicationController + SoftDeletable):
#   * index is scoped to current_organization AND policy_scope(Team), which only
#     resolves ACTIVE teams the user can access through UserPartyRole.
#   * current_organization is the user's first accessible organization (or the
#     one stored in the session), so a user needs an org/team role for index to
#     surface anything.
#   * The controller authorizes every action via TeamPolicy:
#       - show   → team OR organization member
#       - edit/update → TEAM admin only (org admin is NOT sufficient)
#       - new/create/destroy → denied for everyone (policy returns false)
#     Denied actions raise Pundit::NotAuthorizedError, rescued by
#     ApplicationController into a redirect to root_path.
#   * Team includes SoftDeletable, so `destroy` (when it were permitted) is a soft
#     delete; with authorization now enforced, destroy is denied entirely.
#   * Team validates presence of :name, so a blank name re-renders 422.
RSpec.describe "/teams", type: :request do
  let(:organization) { create(:organization, name: "Acme") }
  let(:user) { create(:user) }

  let(:valid_attributes) do
    { name: "Engineering", organization_id: organization.id }
  end

  # A blank name violates the `validates :name, presence: true` rule, so this
  # payload exercises the controller's unprocessable_entity (422) branch.
  let(:invalid_attributes) do
    { name: "", organization_id: organization.id }
  end

  # Parse the response into a Capybara document for scoped assertions
  def doc
    Capybara.string(response.body)
  end

  describe "authentication" do
    it "redirects an unauthenticated visitor away from the index" do
      get teams_url

      expect(response).to redirect_to(root_path)
    end
  end

  context "when signed in as an organization admin" do
    before do
      UserPartyRole.create!(user: user, party: organization, role: "admin")
      sign_in(user)
    end

    describe "GET /index" do
      it "renders a successful response" do
        create(:team, name: "Engineering", organization: organization)

        get teams_url

        expect(response).to be_successful
      end

      it "lists teams belonging to the current organization" do
        create(:team, name: "Engineering", organization: organization)

        get teams_url

        expect(doc).to have_text("Engineering")
      end

      it "excludes teams from other organizations" do
        other_org = create(:organization, name: "Globex")
        create(:team, name: "Foreign Squad", organization: other_org)

        get teams_url

        expect(doc).not_to have_text("Foreign Squad")
      end

      it "excludes soft-deleted teams from the list" do
        create(:team, name: "Live Team", organization: organization)
        create(:team, name: "Archived Team", organization: organization, deleted_at: 1.day.ago)

        get teams_url

        expect(doc).to have_text("Live Team")
        expect(doc).not_to have_text("Archived Team")
      end
    end

    describe "GET /show" do
      it "renders a successful response" do
        team = create(:team, name: "Engineering", organization: organization)

        get team_url(team)

        expect(response).to be_successful
        expect(doc).to have_text("Engineering")
      end
    end

    # new/create/destroy are denied for everyone (TeamPolicy returns false), even
    # for an organization admin. edit/update require a TEAM admin role, which an
    # org admin does not have — so they are denied here too.
    describe "GET /new" do
      it "denies access and redirects to root" do
        get new_team_url

        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /edit" do
      it "denies an org admin who is not a team admin" do
        team = create(:team, name: "Engineering", organization: organization)

        get edit_team_url(team)

        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /create" do
      it "is denied and creates no team" do
        expect {
          post teams_url, params: { team: valid_attributes }
        }.not_to change(Team, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    describe "PATCH /update" do
      it "is denied for an org admin who is not a team admin" do
        team = create(:team, name: "Engineering", organization: organization)

        patch team_url(team), params: { team: { name: "Platform" } }

        expect(team.reload.name).to eq("Engineering")
        expect(response).to redirect_to(root_path)
      end
    end

    describe "DELETE /destroy" do
      it "is denied and leaves the team active" do
        team = create(:team, name: "Engineering", organization: organization)

        expect {
          delete team_url(team)
        }.not_to change { Team.active.exists?(team.id) }

        expect(team.reload.deleted_at).to be_nil
        expect(response).to redirect_to(root_path)
      end
    end
  end

  context "when signed in as a team admin" do
    let(:team) { create(:team, name: "Engineering", organization: organization) }

    before do
      UserPartyRole.create!(user: user, party: team, role: "admin")
      sign_in(user)
    end

    describe "GET /edit" do
      it "renders a successful response" do
        get edit_team_url(team)

        expect(response).to be_successful
      end
    end

    describe "PATCH /update" do
      context "with valid parameters" do
        it "updates the requested team" do
          patch team_url(team), params: { team: { name: "Platform" } }

          expect(team.reload.name).to eq("Platform")
        end

        it "redirects to the team" do
          patch team_url(team), params: { team: { name: "Platform" } }

          expect(response).to redirect_to(team_url(team))
        end
      end

      context "with invalid parameters (blank name)" do
        it "does not change the team" do
          patch team_url(team), params: { team: invalid_attributes }

          expect(team.reload.name).to eq("Engineering")
        end

        it "renders a response with 422 status (i.e. to display the 'edit' template)" do
          patch team_url(team), params: { team: invalid_attributes }

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end
  end
end
