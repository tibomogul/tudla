require 'rails_helper'

RSpec.describe "Links", type: :request do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:linkable) { Linkable.create!(linkable: project) }
  let(:owner) { create(:user, email: "owner@example.com", confirmation_token: "token_owner") }
  let(:authorized_user) { create(:user, email: "authorized@example.com", confirmation_token: "token_authorized") }
  let(:unauthorized_user) { create(:user, email: "unauthorized@example.com", confirmation_token: "token_unauthorized") }

  let(:link) do
    Link.create!(linkable: linkable, user: owner, url: "https://example.com", description: "Test link")
  end

  before do
    UserPartyRole.create!(user: owner, party: organization, role: "member")
    UserPartyRole.create!(user: authorized_user, party: organization, role: "member")
  end

  describe "DELETE /links/:id" do
    context "when authenticated as the link owner" do
      before { sign_in owner }

      it "soft-deletes the link (sets deleted_at, record persists)" do
        test_link = link
        expect {
          delete link_path(test_link)
        }.not_to change(Link.unscoped, :count)

        test_link.reload
        expect(test_link.deleted_at).to be_present
      end

      it "redirects to the parent record" do
        delete link_path(link)
        expect(response).to redirect_to(project_path(project))
      end

      it "makes the link inaccessible via active scope" do
        test_link = link
        delete link_path(test_link)

        expect(Link.active.find_by(id: test_link.id)).to be_nil
      end
    end

    context "when authenticated but not the link owner" do
      before { sign_in authorized_user }

      it "raises Pundit::NotAuthorizedError" do
        expect {
          delete link_path(link)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when authenticated but unauthorized for the project" do
      before { sign_in unauthorized_user }

      it "raises Pundit::NotAuthorizedError" do
        expect {
          delete link_path(link)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when unauthenticated" do
      it "redirects to the root path" do
        delete link_path(link)
        expect(response).to redirect_to(root_path)
      end
    end

    context "with scope parent" do
      let(:scope_record) { create(:scope, project: project) }
      let(:scope_linkable) { Linkable.create!(linkable: scope_record) }
      let(:scope_link) { Link.create!(linkable: scope_linkable, user: owner, url: "https://scope.example.com") }

      before { sign_in owner }

      it "soft-deletes and redirects to the scope" do
        delete link_path(scope_link)

        scope_link.reload
        expect(scope_link.deleted_at).to be_present
        expect(response).to redirect_to(scope_path(scope_record))
      end

      it "excludes soft-deleted link from active scope" do
        lnk = scope_link
        delete link_path(lnk)
        expect(Link.active.find_by(id: lnk.id)).to be_nil
      end
    end

    context "with task parent" do
      let(:task_record) { create(:task, project: project) }
      let(:task_linkable) { Linkable.create!(linkable: task_record) }
      let(:task_link) { Link.create!(linkable: task_linkable, user: owner, url: "https://task.example.com") }

      before { sign_in owner }

      it "soft-deletes and redirects to the task" do
        delete link_path(task_link)

        task_link.reload
        expect(task_link.deleted_at).to be_present
        expect(response).to redirect_to(task_path(task_record))
      end

      it "excludes soft-deleted link from active scope" do
        lnk = task_link
        delete link_path(lnk)
        expect(Link.active.find_by(id: lnk.id)).to be_nil
      end
    end

    context "when link is already soft-deleted" do
      before { sign_in owner }

      it "returns 404" do
        test_link = link
        test_link.soft_delete

        delete link_path(test_link)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
