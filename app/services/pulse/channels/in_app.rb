module Pulse
  module Channels
    # In-app delivery: one Pulse::Notification row per recipient.
    # create_or_find_by keeps the broadcast callback firing for new rows while
    # the unique [event_id, user_id] index makes job retries no-ops.
    class InApp < Base
      def deliver(event, recipients)
        recipients.each do |recipient|
          Pulse::Notification.create_or_find_by!(event: event, user: recipient)
        end
      end
    end
  end
end
