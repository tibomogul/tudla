require 'rails_helper'

RSpec.describe "Attachments", type: :request do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:attachable) { Attachable.create!(attachable: project) }
  let(:uploader) { create(:user, email: "uploader@example.com", confirmation_token: "token_uploader") }
  let(:authorized_user) { create(:user, email: "authorized@example.com", confirmation_token: "token_authorized") }
  let(:unauthorized_user) { create(:user, email: "unauthorized@example.com", confirmation_token: "token_unauthorized") }

  let(:image_attachment) do
    attachment = Attachment.new(attachable: attachable, user: uploader)
    attachment.file.attach(
      io: StringIO.new("fake image data"),
      filename: "photo.png",
      content_type: "image/png"
    )
    attachment.save!
    attachment
  end

  let(:zip_attachment) do
    attachment = Attachment.new(attachable: attachable, user: uploader)
    attachment.file.attach(
      io: StringIO.new("fake zip data"),
      filename: "archive.zip",
      content_type: "application/zip"
    )
    attachment.save!
    attachment
  end

  before do
    UserPartyRole.create!(user: uploader, party: organization, role: "member")
    UserPartyRole.create!(user: authorized_user, party: organization, role: "member")
  end

  describe "GET /attachments/:id/download" do
    context "when authenticated and authorized" do
      before { sign_in authorized_user }

      it "redirects to the blob URL" do
        get download_attachment_path(image_attachment)
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/rails/active_storage")
      end
    end

    context "when authenticated but unauthorized" do
      before { sign_in unauthorized_user }

      it "raises Pundit::NotAuthorizedError" do
        expect {
          get download_attachment_path(image_attachment)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when unauthenticated" do
      it "redirects to the root path" do
        get download_attachment_path(image_attachment)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /attachments/:id" do
    context "when authenticated and authorized" do
      before { sign_in authorized_user }

      it "soft-deletes the attachment (sets deleted_at, record persists)" do
        attachment = image_attachment
        expect {
          delete attachment_path(attachment)
        }.not_to change(Attachment.unscoped, :count)

        attachment.reload
        expect(attachment.deleted_at).to be_present
      end

      it "redirects to the parent record" do
        delete attachment_path(image_attachment)
        expect(response).to redirect_to(project_path(project))
      end

      it "makes the attachment inaccessible via active scope" do
        attachment = image_attachment
        delete attachment_path(attachment)

        expect(Attachment.active.find_by(id: attachment.id)).to be_nil
      end
    end

    context "when authenticated but unauthorized" do
      before { sign_in unauthorized_user }

      it "raises Pundit::NotAuthorizedError" do
        expect {
          delete attachment_path(image_attachment)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when unauthenticated" do
      it "redirects to the root path" do
        delete attachment_path(image_attachment)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when attachment is already soft-deleted" do
      before { sign_in authorized_user }

      it "returns 404" do
        attachment = image_attachment
        attachment.soft_delete

        delete attachment_path(attachment)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /attachments/:id (scope parent)" do
    let(:scope_record) { create(:scope, project: project) }
    let(:scope_attachable) { Attachable.create!(attachable: scope_record) }
    let(:scope_attachment) do
      attachment = Attachment.new(attachable: scope_attachable, user: uploader)
      attachment.file.attach(io: StringIO.new("scope file"), filename: "scope.png", content_type: "image/png")
      attachment.save!
      attachment
    end

    before { sign_in authorized_user }

    it "soft-deletes and redirects to the scope" do
      delete attachment_path(scope_attachment)

      scope_attachment.reload
      expect(scope_attachment.deleted_at).to be_present
      expect(response).to redirect_to(scope_path(scope_record))
    end

    it "excludes soft-deleted attachment from active scope" do
      att = scope_attachment
      delete attachment_path(att)
      expect(Attachment.active.find_by(id: att.id)).to be_nil
    end
  end

  describe "DELETE /attachments/:id (task parent)" do
    let(:task_record) { create(:task, project: project) }
    let(:task_attachable) { Attachable.create!(attachable: task_record) }
    let(:task_attachment) do
      attachment = Attachment.new(attachable: task_attachable, user: uploader)
      attachment.file.attach(io: StringIO.new("task file"), filename: "task.png", content_type: "image/png")
      attachment.save!
      attachment
    end

    before { sign_in authorized_user }

    it "soft-deletes and redirects to the task" do
      delete attachment_path(task_attachment)

      task_attachment.reload
      expect(task_attachment.deleted_at).to be_present
      expect(response).to redirect_to(task_path(task_record))
    end

    it "excludes soft-deleted attachment from active scope" do
      att = task_attachment
      delete attachment_path(att)
      expect(Attachment.active.find_by(id: att.id)).to be_nil
    end
  end

  describe "GET /attachments/:id/preview" do
    context "when authenticated and authorized" do
      before { sign_in authorized_user }

      it "redirects to the inline blob URL for a previewable file" do
        get preview_attachment_path(image_attachment)
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/rails/active_storage")
      end

      it "returns 404 for a non-previewable file" do
        get preview_attachment_path(zip_attachment)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when authenticated but unauthorized" do
      before { sign_in unauthorized_user }

      it "raises Pundit::NotAuthorizedError" do
        expect {
          get preview_attachment_path(image_attachment)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "when unauthenticated" do
      it "redirects to the root path" do
        get preview_attachment_path(image_attachment)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
