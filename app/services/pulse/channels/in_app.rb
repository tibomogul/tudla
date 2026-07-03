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

        recipients.each do |recipient|
          Pulse::Notification.broadcast_indicator_for(recipient) if inserted_ids.include?(recipient.id)
        end
      end
    end
  end
end
