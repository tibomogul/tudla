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

  describe "GET /notes/:id" do
    context "when authenticated as a member of the parent org" do
      before { sign_in authorized_user }

      it "renders the show partial inside the shared turbo frame on Turbo Frame requests" do
        get note_path(note), headers: { "Turbo-Frame" => "note_modal_frame" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Test Note")
        expect(response.body).to include("Test note content")
        expect(response.body).to include('id="note_modal_frame"')
      end

      it "redirects to the parent project with an anchor on a plain HTML request" do
        get note_path(note)
        expect(response).to redirect_to(project_path(project, anchor: ActionView::RecordIdentifier.dom_id(note)))
      end

      it "redirects to the parent scope when notable is a Scope" do
        scope_record = create(:scope, project: project)
        scope_notable = Notable.create!(notable: scope_record)
        scope_note = Note.create!(notable: scope_notable, user: owner, content: "Scope note", title: "S")
        get note_path(scope_note)
        expect(response).to redirect_to(scope_path(scope_record, anchor: ActionView::RecordIdentifier.dom_id(scope_note)))
      end

      it "redirects to the parent task when notable is a Task" do
        task_record = create(:task, project: project)
        task_notable = Notable.create!(notable: task_record)
        task_note = Note.create!(notable: task_notable, user: owner, content: "Task note", title: "T")
        get note_path(task_note)
        expect(response).to redirect_to(task_path(task_record, anchor: ActionView::RecordIdentifier.dom_id(task_note)))
      end
    end

    context "when authenticated but unauthorized" do
      before { sign_in unauthorized_user }

      it "redirects with a not-authorized flash" do
        get note_path(note)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to match(/not authorized/i)
      end
    end

    context "when the note is soft-deleted" do
      before { sign_in owner }

      it "returns 404" do
        note.soft_delete
        get note_path(note)
        expect(response).to have_http_status(:not_found)
      end
    end
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

      it "redirects with a not-authorized flash and does not delete" do
        delete note_path(note)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to match(/not authorized/i)
        note.reload
        expect(note.deleted_at).to be_nil
      end
    end

    context "when authenticated but unauthorized for the project" do
      before { sign_in unauthorized_user }

      it "redirects with a not-authorized flash" do
        delete note_path(note)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to match(/not authorized/i)
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
