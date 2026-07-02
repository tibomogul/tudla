module Pulse
  # Per-request/job actor context for event attribution. Set by
  # ApplicationController (signed-in users), McpController (AI agents);
  # anything else (jobs, console, rake) falls back to the "system" actor.
  class Current < ActiveSupport::CurrentAttributes
    attribute :user, :actor_type, :actor_label

    def self.resolved_actor_type
      actor_type.presence || (user ? "user" : "system")
    end
  end
end
