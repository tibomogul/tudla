module Pulse
  module Channels
    # In-app delivery: one Pulse::Notification row per recipient, written in
    # a single insert_all statement. The unique [event_id, user_id] index
    # (ON CONFLICT DO NOTHING) makes job retries no-ops, and `returning`
    # limits bell broadcasts to rows actually inserted — insert_all skips AR
    # callbacks, so the broadcast is triggered explicitly here.
    class InApp < Base
      def deliver(event, recipients)
        return if recipients.empty?

        inserted = Pulse::Notification.insert_all(
          recipients.map { |recipient| { event_id: event.id, user_id: recipient.id } },
          unique_by: [ :event_id, :user_id ],
          returning: [ :user_id ]
        )
        inserted_ids = inserted.rows.flatten.to_set
        return if inserted_ids.empty?

        # One grouped COUNT for every badge; without it each broadcast render
        # would run its own per-user unread COUNT inside the indicator partial.
        unread_counts = Pulse::Notification.unread.where(user_id: inserted_ids.to_a)
          .group(:user_id).count

        recipients.each do |recipient|
          next unless inserted_ids.include?(recipient.id)

          Pulse::Notification.broadcast_indicator_for(
            recipient, unread_count: unread_counts.fetch(recipient.id, 0)
          )
        end
      end
    end
  end
end
