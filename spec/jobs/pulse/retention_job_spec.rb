require "rails_helper"

RSpec.describe Pulse::RetentionJob, type: :job do
  let(:user) { create(:user) }

  around { |ex| travel_to(Time.zone.local(2026, 7, 5, 9)) { ex.run } }

  describe "notification retention" do
    it "deletes read notifications older than 30 days and keeps recently read ones" do
      old_read = create(:pulse_notification, user: user, read_at: 31.days.ago)
      recent_read = create(:pulse_notification, user: user, read_at: 29.days.ago)

      described_class.perform_now

      expect(Pulse::Notification.exists?(old_read.id)).to be false
      expect(Pulse::Notification.exists?(recent_read.id)).to be true
    end

    it "deletes unread notifications older than 90 days and keeps younger unread ones" do
      stale_unread = create(:pulse_notification, user: user, created_at: 91.days.ago)
      fresh_unread = create(:pulse_notification, user: user, created_at: 89.days.ago)

      described_class.perform_now

      expect(Pulse::Notification.exists?(stale_unread.id)).to be false
      expect(Pulse::Notification.exists?(fresh_unread.id)).to be true
    end
  end

  describe "event retention" do
    it "deletes events older than 90 days that have no notifications left" do
      old_event = create(:pulse_event, created_at: 91.days.ago)

      described_class.perform_now

      expect(Pulse::Event.exists?(old_event.id)).to be false
    end

    it "keeps recent events even without notifications" do
      recent_event = create(:pulse_event, created_at: 89.days.ago)

      described_class.perform_now

      expect(Pulse::Event.exists?(recent_event.id)).to be true
    end

    it "keeps old events that still have a live notification" do
      old_event = create(:pulse_event, created_at: 91.days.ago)
      notification = create(:pulse_notification, user: user, event: old_event)

      described_class.perform_now

      expect(Pulse::Event.exists?(old_event.id)).to be true
      expect(Pulse::Notification.exists?(notification.id)).to be true
    end

    it "purges an old event in the same run its last notification expires" do
      old_event = create(:pulse_event, created_at: 91.days.ago)
      create(:pulse_notification, user: user, event: old_event,
                                  created_at: 91.days.ago, read_at: 31.days.ago)

      described_class.perform_now

      expect(Pulse::Event.exists?(old_event.id)).to be false
    end
  end
end
