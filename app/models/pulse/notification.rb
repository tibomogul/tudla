module Pulse
  class Notification < ApplicationRecord
    belongs_to :user
    belongs_to :event, class_name: "Pulse::Event"

    scope :unread, -> { where(read_at: nil) }
    scope :read, -> { where.not(read_at: nil) }

    after_create_commit :broadcast_notification_indicator
    after_update_commit :broadcast_notification_indicator, if: :saved_change_to_read_at?

    def read?
      read_at.present?
    end

    def mark_read!
      update!(read_at: Time.current) unless read?
    end

    def self.policy_class
      NotificationPolicy
    end

    # Live-updates the topbar bell for a user. Class-level (via
    # Turbo::StreamsChannel) because mark_all_read uses update_all, which has
    # no instances to fire callbacks on. Guarded like the other model
    # broadcasts: skip when ActionCable isn't available (tests, rake) and
    # never let a broadcast failure break the caller.
    def self.broadcast_indicator_for(user)
      return unless ActionCable.server.pubsub.respond_to?(:broadcast)

      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{user.id}_notifications",
        target: "notifications_indicator",
        partial: "notifications/indicator",
        locals: { user: user, can_update: false }
      )
    rescue => e
      Rails.logger.error "Pulse::Notification broadcast failed: #{e.message}"
    end

    private

    def broadcast_notification_indicator
      self.class.broadcast_indicator_for(user)
    end
  end
end
