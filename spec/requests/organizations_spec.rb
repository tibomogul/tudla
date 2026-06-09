require "rails_helper"

# Request specs for OrganizationsController.
#
# Behaviour notes that shape these examples (see OrganizationsController +
# ApplicationController + OrganizationPolicy + SoftDeletable):
#   * index calls `policy_scope(Organization)`, whose Scope resolves only ACTIVE
#     organizations on which the user holds an Organization-level UserPartyRole.
#     A team/project-only role does NOT surface the org in the index, and
#     soft-deleted orgs are filtered out by `scope.active`.
#   * The controller authorizes every action via OrganizationPolicy:
#       - show        → organization member
#       - edit/update → organization ADMIN
#       - new/create/destroy → denied for everyone (policy returns false)
#     Denied actions raise Pundit::NotAuthorizedError, rescued by
#     ApplicationController into a redirect to root_path.
#   * Organization includes SoftDeletable; with authorization enforced, destroy is
#     denied entirely. update redirects with :see_other.
#   * Organization validates presence of :name, so a blank name re-renders 422.
RSpec.describe "/organizations", type: :request do
  let(:user) { create(:user) }

  let(:valid_attributes) do
    { name: "Acme Corp" }
  end

  # Parse the response into a Capybara document for scoped assertions.
  def doc
    Capybara.string(response.body)
  end

  describe "authentication" do
    it "redirects an unauthenticated visitor away from the index" do
      get organizations_url

      expect(response).to redirect_to(root_path)
    end
  end

  context "when signed in as an organization admin" do
    let(:organization) { create(:organization, name: "Acme Corp") }

    before do
      UserPartyRole.create!(user: user, party: organization, role: "admin")
      sign_in(user)
    end

    describe "GET /index" do
      it "renders a successful response" do
        get organizations_url

        expect(response).to be_successful
      end

      it "lists organizations the user has an org role on" do
        get organizations_url

        expect(doc).to have_text("Acme Corp")
      end

      it "excludes organizations the user has no role on" do
        create(:organization, name: "Globex")

        get organizations_url

        expect(doc).not_to have_text("Globex")
      end

      it "excludes soft-deleted organizations from the list" do
        other = create(:organization, name: "Archived Org")
        UserPartyRole.create!(user: user, party: other, role: "admin")
        other.soft_delete

        get organizations_url

        expect(doc).to have_text("Acme Corp")
        expect(doc).not_to have_text("Archived Org")
      end
    end

    describe "GET /show" do
      it "renders a successful response" do
        get organization_url(organization)

        expect(response).to be_successful
        expect(doc).to have_text("Acme Corp")
      end
    end

    # new/create/destroy are denied for everyone (OrganizationPolicy returns
    # false), even for an org admin. edit/update remain available to org admins.
    describe "GET /new" do
      it "denies access and redirects to root" do
        get new_organization_url

        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /edit" do
      it "renders a successful response" do
        get edit_organization_url(organization)

        expect(response).to be_successful
      end
    end

    describe "POST /create" do
      it "is denied and creates no organization" do
        expect {
          post organizations_url, params: { organization: valid_attributes }
        }.not_to change(Organization, :count)

        expect(response).to redirect_to(root_path)
      end
    end

    describe "PATCH /update" do
      context "with valid parameters" do
        let(:new_attributes) { { name: "Acme Industries" } }

        it "updates the requested organization" do
          patch organization_url(organization), params: { organization: new_attributes }

          expect(organization.reload.name).to eq("Acme Industries")
        end

        it "redirects to the organization" do
          patch organization_url(organization), params: { organization: new_attributes }

          expect(response).to redirect_to(organization_url(organization))
        end
      end

      context "with invalid parameters (blank name)" do
        it "does not change the organization" do
          patch organization_url(organization), params: { organization: { name: "" } }

          expect(organization.reload.name).to eq("Acme Corp")
        end

        it "renders a response with 422 status (i.e. to display the 'edit' template)" do
          patch organization_url(organization), params: { organization: { name: "" } }

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      # Non-permitted params (e.g. LLM settings) are filtered out by
      # `params.expect(organization: [:name])` and never reach the model, so they
      # cannot trigger the model's LLM-completeness validation. The name-only
      # payload always succeeds.
      it "ignores params outside the permitted :name list" do
        patch organization_url(organization),
          params: { organization: { name: "Renamed", llm_model: "gpt-4" } }

        organization.reload
        expect(organization.name).to eq("Renamed")
        expect(organization.llm_model).to be_nil
        expect(response).to redirect_to(organization_url(organization))
      end
    end

    describe "DELETE /destroy" do
      it "is denied and leaves the organization active" do
        expect {
          delete organization_url(organization)
        }.not_to change { Organization.active.exists?(organization.id) }

        expect(organization.reload.deleted_at).to be_nil
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
