module Pulse
  module Channels
    # Channel adapter interface. Implementations (in-app, and later email or
    # Slack) are registered by class name in Pulse.config.channels; adding a
    # channel never requires touching orchestration.
    class Base
      def deliver(event, recipients)
        raise NotImplementedError, "#{self.class} must implement #deliver(event, recipients)"
      end
    end
  end
end
