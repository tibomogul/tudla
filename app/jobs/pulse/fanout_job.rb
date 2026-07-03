module Pulse
  # Orchestration pillar: resolves recipients for a published event and hands
  # them to each configured channel. Idempotent — the unique index on
  # notifications [event_id, user_id] makes retries no-ops for the in-app
  # channel, so partial failures can safely re-run.
  class FanoutJob < ApplicationJob
    queue_as :default

    def perform(event_id)
      event = Pulse::Event.find_by(id: event_id)
      unless event
        Rails.logger.warn("[Pulse::FanoutJob] Event ##{event_id} no longer exists, skipping")
        return
      end

      recipients = eligible_recipients(event)
      return if recipients.empty?

      Pulse.channels.each { |channel| channel.new.deliver(event, recipients) }
    end

    private

    # Soft-deleted users are filtered here (not in the resolver) so the rule
    # also covers custom recipient resolvers.
    def eligible_recipients(event)
      candidates = Pulse.recipient_resolver.call(event).uniq.reject do |recipient|
        recipient == event.user || recipient.deleted?
      end
      return [] if candidates.empty?

      subject = event.subscribable.subscribable
      return [] unless subject

      # Access-revocation safety: never notify a user who can no longer see
      # the underlying subject. A filter failure counts as "not visible".
      begin
        Pulse.visibility_filter.call(subject, candidates)
      rescue StandardError => e
        Rails.logger.error("[Pulse::FanoutJob] Visibility filtering failed for event ##{event.id}: " \
                           "#{e.class}: #{e.message}")
        []
      end
    end
  end
end
