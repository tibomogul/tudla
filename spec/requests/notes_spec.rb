require 'rails_helper'

RSpec.describe "Notes", type: :request do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:notable) { Notable.create!(notable: project) }
  let(:owner) { create(:user, email: "owner@example.com", confirmation_token: "token_owner") }
  let(:authorized_user) { create(:user, email: "authorized@example.com", confirmation_token: "token_authorized") }
  let(:unauthorized_user) { create(:user, email: "unauthorized@example.com", confirmation_token: "token_unauthorized") }

  let(:note) do
    Note.create!(notable: notable, user: owner, content: "Test note content", title: "Test Note")
  end

  before do
    UserPartyRole.create!(user: owner, party: organization, role: "member")
    UserPartyRole.create!(user: authorized_user, party: organization, role: "member")
  end

  describe "DELETE /notes/:id" do
    context "when authenticated as the note owner" do
      before { sign_in owner }

      it "soft-deletes the note (sets deleted_at, record persists)" do
        test_note = note
        expect {
          delete note_path(test_note)
        }.not_to change(Note.unscoped, :count)

        test_note.reload
        expect(test_note.deleted_at).to be_present
      end

      it "redirects to the parent record" do
        delete note_path(note)
        expect(response).to redirect_to(project_path(project))
      end

      it "makes the note inaccessible via active scope" do
        test_note = note
        delete note_path(test_note)

        expect(Note.active.find_by(id: test_note.id)).to be_nil
      end
    end

    context "when authenticated but not the note owner" do
      before { sign_in authorized_user }

      it "raises Pundit::NotAuthorizedError" do
        expect {
          delete note_path(note)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when authenticated but unauthorized for the project" do
      before { sign_in unauthorized_user }

      it "raises Pundit::NotAuthorizedError" do
        expect {
          delete note_path(note)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when unauthenticated" do
      it "redirects to the root path" do
        delete note_path(note)
        expect(response).to redirect_to(root_path)
      end
    end

    context "with scope parent" do
      let(:scope_record) { create(:scope, project: project) }
      let(:scope_notable) { Notable.create!(notable: scope_record) }
      let(:scope_note) { Note.create!(notable: scope_notable, user: owner, content: "Scope note", title: "Scope") }

      before { sign_in owner }

      it "soft-deletes and redirects to the scope" do
        delete note_path(scope_note)

        scope_note.reload
        expect(scope_note.deleted_at).to be_present
        expect(response).to redirect_to(scope_path(scope_record))
      end

      it "excludes soft-deleted note from active scope" do
        n = scope_note
        delete note_path(n)
        expect(Note.active.find_by(id: n.id)).to be_nil
      end
    end

    context "with task parent" do
      let(:task_record) { create(:task, project: project) }
      let(:task_notable) { Notable.create!(notable: task_record) }
      let(:task_note) { Note.create!(notable: task_notable, user: owner, content: "Task note", title: "Task") }

      before { sign_in owner }

      it "soft-deletes and redirects to the task" do
        delete note_path(task_note)

        task_note.reload
        expect(task_note.deleted_at).to be_present
        expect(response).to redirect_to(task_path(task_record))
      end

      it "excludes soft-deleted note from active scope" do
        n = task_note
        delete note_path(n)
        expect(Note.active.find_by(id: n.id)).to be_nil
      end
    end

    context "when note is already soft-deleted" do
      before { sign_in owner }

      it "returns 404" do
        test_note = note
        test_note.soft_delete

        delete note_path(test_note)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
