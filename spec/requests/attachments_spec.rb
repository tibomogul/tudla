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
