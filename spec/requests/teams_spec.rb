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
#   * The controller does NOT call `authorize` on create/update/destroy, so those
#     actions are reachable by any signed-in user — these specs lock in the
#     actual behaviour, not the (stricter) TeamPolicy booleans.
#   * Team includes SoftDeletable, so `destroy` is a soft delete: it sets
#     deleted_at and removes the team from `Team.active`, but the raw `Team.count`
#     row count is unchanged.
RSpec.describe "/teams", type: :request do
  let(:organization) { create(:organization, name: "Acme") }
  let(:user) { create(:user) }

  let(:valid_attributes) do
    { name: "Engineering", organization_id: organization.id }
  end

  # Team's only validation is the required `organization` association (belongs_to),
  # so an invalid payload is one whose organization_id does not resolve to a record.
  let(:invalid_attributes) do
    { name: "Orphan Team", organization_id: nil }
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

    describe "GET /new" do
      it "renders a successful response" do
        get new_team_url

        expect(response).to be_successful
      end
    end

    describe "GET /edit" do
      it "renders a successful response" do
        team = create(:team, name: "Engineering", organization: organization)

        get edit_team_url(team)

        expect(response).to be_successful
      end
    end

    describe "POST /create" do
      context "with valid parameters" do
        it "creates a new Team" do
          expect {
            post teams_url, params: { team: valid_attributes }
          }.to change(Team, :count).by(1)
        end

        it "persists the submitted attributes" do
          post teams_url, params: { team: valid_attributes }

          team = Team.last
          expect(team.name).to eq("Engineering")
          expect(team.organization).to eq(organization)
        end

        it "redirects to the created team" do
          post teams_url, params: { team: valid_attributes }

          expect(response).to redirect_to(team_url(Team.last))
        end
      end

      context "with invalid parameters" do
        it "does not create a new Team" do
          expect {
            post teams_url, params: { team: invalid_attributes }
          }.not_to change(Team, :count)
        end

        it "renders a response with 422 status (i.e. to display the 'new' template)" do
          post teams_url, params: { team: invalid_attributes }

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe "PATCH /update" do
      let(:team) { create(:team, name: "Engineering", organization: organization) }

      context "with valid parameters" do
        let(:new_attributes) { { name: "Platform" } }

        it "updates the requested team" do
          patch team_url(team), params: { team: new_attributes }

          expect(team.reload.name).to eq("Platform")
        end

        it "redirects to the team" do
          patch team_url(team), params: { team: new_attributes }

          expect(response).to redirect_to(team_url(team))
        end
      end

      context "with invalid parameters" do
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

    describe "DELETE /destroy" do
      it "soft-deletes the requested team" do
        team = create(:team, name: "Engineering", organization: organization)

        expect {
          delete team_url(team)
        }.to change { Team.active.exists?(team.id) }.from(true).to(false)

        expect(team.reload.deleted_at).to be_present
      end

      it "does not hard-delete the row" do
        team = create(:team, name: "Engineering", organization: organization)

        expect {
          delete team_url(team)
        }.not_to change(Team, :count)
      end

      it "redirects to the teams list" do
        team = create(:team, name: "Engineering", organization: organization)

        delete team_url(team)

        expect(response).to redirect_to(teams_url)
      end
    end
  end
end
