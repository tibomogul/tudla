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
      Pulse.recipient_resolver.call(event).uniq.reject do |recipient|
        recipient == event.user || recipient.deleted? || !visible_to?(recipient, event)
      end
    end

    # Access-revocation safety: never notify a user who can no longer see the
    # underlying subject. Errors count as "not visible".
    def visible_to?(recipient, event)
      subject = event.subscribable.subscribable
      return false unless subject

      Pundit.policy!(recipient, subject).show?
    rescue StandardError => e
      Rails.logger.error("[Pulse::FanoutJob] Visibility check failed for user ##{recipient.id} " \
                         "on event ##{event.id}: #{e.class}: #{e.message}")
      false
    end
  end
end
