require "rails_helper"

RSpec.describe "/notifications", type: :request do
  let(:organization) { create(:organization) }
  let(:team) { create(:team, organization: organization) }
  let(:project) { create(:project, team: team) }
  let(:user) { create(:user) }

  before do
    UserPartyRole.create!(user: user, party: organization, role: "member")
    sign_in(user)
  end

  def create_notification(recipient: user, action: "project.updated")
    event = Pulse::Publisher.publish(subject: project, action: action, user: create(:user))
    Pulse::Notification.create!(event: event, user: recipient)
  end

  describe "GET /notifications" do
    it "lists only the current user's notifications" do
      mine = create_notification
      create_notification(recipient: create(:user))

      get notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(mark_read_notification_path(mine))
      expect(Capybara.string(response.body)).to have_css("a[href*='/notifications/'][href*='mark_read']", count: 1)
    end
  end

  describe "PATCH /notifications/:id/mark_read" do
    it "marks the notification read and redirects to the subject" do
      notification = create_notification

      patch mark_read_notification_path(notification)

      expect(notification.reload.read?).to be true
      expect(response).to redirect_to(project_path(project))
    end

    it "falls back to the inbox when the subject has been soft-deleted" do
      notification = create_notification
      project.soft_delete

      patch mark_read_notification_path(notification)

      expect(notification.reload.read?).to be true
      expect(response).to redirect_to(notifications_path)
    end

    it "rejects another user's notification" do
      other_notification = create_notification(recipient: create(:user))

      patch mark_read_notification_path(other_notification)

      expect(response).to have_http_status(:not_found)
      expect(other_notification.reload.read?).to be false
    end
  end

  describe "PATCH /notifications/mark_all_read" do
    it "marks all of the user's unread notifications read, leaving others untouched" do
      mine = [ create_notification, create_notification ]
      other = create_notification(recipient: create(:user))

      patch mark_all_read_notifications_path

      expect(mine.each(&:reload).map(&:read?)).to all(be true)
      expect(other.reload.read?).to be false
      expect(response).to redirect_to(notifications_path)
    end
  end
end
