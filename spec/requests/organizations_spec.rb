require "rails_helper"

# Request specs for OrganizationsController.
#
# Behaviour notes that shape these examples (see OrganizationsController +
# ApplicationController + OrganizationPolicy + SoftDeletable):
#   * index calls `policy_scope(Organization)`, whose Scope resolves only ACTIVE
#     organizations on which the user holds an Organization-level UserPartyRole.
#     A team/project-only role does NOT surface the org in the index, and
#     soft-deleted orgs are filtered out by `scope.active`.
#   * show/edit use `set_organization` (`Organization.find`) and the controller
#     does NOT call `authorize`, so those actions — like create/update/destroy —
#     are reachable by any signed-in user. These specs lock in the ACTUAL
#     controller behaviour, not the (stricter) OrganizationPolicy booleans
#     (create?/destroy? are false, show?/update? gate on membership/admin).
#   * Organization includes SoftDeletable, so `destroy` is a soft delete: it sets
#     deleted_at and removes the org from `Organization.active`, but the raw
#     `Organization.count` row count is unchanged. The redirect uses :see_other.
#   * update also redirects with :see_other.
#   * Only `:name` is a permitted param and `name` has no presence validation
#     (nullable column, no model validation), so a payload submitted through the
#     permitted params can never fail validation — there is no reachable 422
#     path. The "blank name" examples document that real behaviour instead.
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

    describe "GET /new" do
      it "renders a successful response" do
        get new_organization_url

        expect(response).to be_successful
      end
    end

    describe "GET /edit" do
      it "renders a successful response" do
        get edit_organization_url(organization)

        expect(response).to be_successful
      end
    end

    describe "POST /create" do
      it "creates a new Organization" do
        expect {
          post organizations_url, params: { organization: valid_attributes }
        }.to change(Organization, :count).by(1)
      end

      it "persists the submitted attributes" do
        post organizations_url, params: { organization: { name: "Initech" } }

        expect(Organization.last.name).to eq("Initech")
      end

      it "redirects to the created organization" do
        post organizations_url, params: { organization: valid_attributes }

        expect(response).to redirect_to(organization_url(Organization.last))
      end

      # Only :name is permitted and it has no presence validation, so even a
      # blank name persists — documenting that there is no reachable 422 path.
      it "still creates an organization with a blank name" do
        expect {
          post organizations_url, params: { organization: { name: "" } }
        }.to change(Organization, :count).by(1)

        expect(response).to redirect_to(organization_url(Organization.last))
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
      it "soft-deletes the requested organization" do
        expect {
          delete organization_url(organization)
        }.to change { Organization.active.exists?(organization.id) }.from(true).to(false)

        expect(organization.reload.deleted_at).to be_present
      end

      it "does not hard-delete the row" do
        org = organization

        expect {
          delete organization_url(org)
        }.not_to change(Organization, :count)
      end

      it "redirects to the organizations list" do
        delete organization_url(organization)

        expect(response).to redirect_to(organizations_url)
      end
    end
  end
end
