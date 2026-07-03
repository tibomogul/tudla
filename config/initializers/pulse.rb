# Host-app wiring for the Pulse notification pipeline. All app-specific
# knowledge (which models are subscribable, how recipients are resolved,
# which channels deliver) is declared here so app/models/pulse and
# app/services/pulse stay extractable.
Rails.application.config.to_prepare do
  Pulse.configure do |config|
    config.subscribable_types = %w[Project Scope Task]
    config.channels = [ "Pulse::Channels::InApp" ]
    config.recipient_resolver = "PulseRecipientResolver"
    config.visibility_filter = "PulseVisibilityFilter"
  end
end
