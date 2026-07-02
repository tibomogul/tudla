require "rails_helper"

RSpec.describe NotificationPolicy do
  let(:user) { create(:user) }
  let(:notification) { create(:pulse_notification, user: user) }

  describe "#mark_read?" do
    it "allows the recipient" do
      expect(described_class.new(user, notification).mark_read?).to be true
    end

    it "denies another user" do
      expect(described_class.new(create(:user), notification).mark_read?).to be false
    end
  end

  describe "Scope" do
    it "returns only the user's notifications" do
      mine = create(:pulse_notification, user: user)
      create(:pulse_notification)

      resolved = described_class::Scope.new(user, Pulse::Notification.all).resolve

      expect(resolved).to contain_exactly(mine)
    end
  end
end
