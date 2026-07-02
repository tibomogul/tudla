module Pulse
  # Default recipient resolution: everyone subscribed to the event's
  # subscribable. Host apps extend this via config.recipient_resolver
  # (see PulseRecipientResolver) to add domain-specific rules.
  class RecipientResolver
    def call(event)
      event.subscribable.subscriptions.includes(:user).map(&:user)
    end
  end
end
