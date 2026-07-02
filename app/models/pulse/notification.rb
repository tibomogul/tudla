module Pulse
  class Notification < ApplicationRecord
    belongs_to :user
    belongs_to :event, class_name: "Pulse::Event"

    scope :unread, -> { where(read_at: nil) }
    scope :read, -> { where.not(read_at: nil) }

    after_create_commit :broadcast_notification_indicator

    def read?
      read_at.present?
    end

    def mark_read!
      update!(read_at: Time.current) unless read?
    end

    def self.policy_class
      NotificationPolicy
    end

    private

    # Live-updates the topbar bell for the recipient. Guarded like the other
    # model broadcasts: skip when ActionCable isn't available (tests, rake) and
    # never let a broadcast failure break notification creation.
    def broadcast_notification_indicator
      return unless defined?(Turbo::StreamsChannel) && ActionCable.server.respond_to?(:broadcast)

      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user_id}_notifications",
        target: "notifications_indicator",
        partial: "notifications/indicator",
        locals: { user: user, can_update: false }
      )
    rescue => e
      Rails.logger.error "Pulse::Notification broadcast failed: #{e.message}"
    end
  end
end
