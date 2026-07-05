module Pulse
  # Retention for the notification pipeline. Fan-out on write means rows grow
  # as events × recipients, and nothing else ever prunes them. Scheduled daily
  # via config/recurring.yml (Solid Queue).
  #
  # Everything is delete_all in primary-key batches: Pulse::Notification has
  # no destroy callbacks (broadcasts fire on create/update only) and events
  # are only deleted once no notifications reference them, so skipping AR
  # callbacks/dependent hooks is safe. Badge counts are not re-broadcast —
  # pruning unread rows is corrected on the user's next page load.
  class RetentionJob < ApplicationJob
    queue_as :default

    READ_NOTIFICATION_RETENTION = 30.days
    UNREAD_NOTIFICATION_RETENTION = 90.days
    EVENT_RETENTION = 90.days
    BATCH_SIZE = 1_000

    def perform
      purged_read = purge_in_batches(
        Pulse::Notification.read.where(read_at: ...READ_NOTIFICATION_RETENTION.ago)
      )
      purged_unread = purge_in_batches(
        Pulse::Notification.unread.where(created_at: ...UNREAD_NOTIFICATION_RETENTION.ago)
      )
      # Events must outlive their notifications (belongs_to + FK), so only
      # events with no remaining notifications are eligible.
      purged_events = purge_in_batches(
        Pulse::Event
          .where(created_at: ...EVENT_RETENTION.ago)
          .where("NOT EXISTS (SELECT 1 FROM notifications WHERE notifications.event_id = events.id)")
      )

      Rails.logger.info(
        "[Pulse::RetentionJob] purged #{purged_read} read + #{purged_unread} unread " \
        "notifications, #{purged_events} events"
      )
    end

    private

    def purge_in_batches(relation)
      purged = 0
      relation.in_batches(of: BATCH_SIZE) { |batch| purged += batch.delete_all }
      purged
    end
  end
end
