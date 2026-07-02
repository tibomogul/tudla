module Pulse
  # Producer pillar: mixed into host models (Project/Scope/Task) to auto-create
  # their Subscribable container and publish lifecycle events.
  #
  # Include AFTER SoftDeletable — the soft_delete/restore overrides below rely
  # on `super`, and SoftDeletable's update_column-based implementation fires no
  # AR callbacks, so deletion events can only be published here.
  module Publishable
    extend ActiveSupport::Concern

    included do
      class_attribute :pulse_event_prefix, instance_writer: false
      class_attribute :pulse_ignored_columns, instance_writer: false, default: [].freeze

      after_create :create_pulse_subscribable
    end

    class_methods do
      def publishes_pulse_events(prefix:, ignore: [])
        self.pulse_event_prefix = prefix.to_s
        self.pulse_ignored_columns = (ignore.map(&:to_s) + %w[id created_at updated_at]).freeze

        after_create :publish_pulse_created_event
        after_update :publish_pulse_updated_event
      end
    end

    def pulse_subscribable
      subscribable || create_pulse_subscribable
    end

    def pulse_subscribers
      pulse_subscribable.users
    end

    def subscribed?(user)
      pulse_subscribable.subscriptions.exists?(user: user)
    end

    def subscribe(user)
      return unless user

      Pulse::Subscription.create_or_find_by!(user: user, subscribable: pulse_subscribable)
    end

    def unsubscribe(user)
      pulse_subscribable.subscriptions.where(user: user).destroy_all
    end

    def publish_pulse_event(action, metadata: {}, **publish_options)
      Pulse::Publisher.publish(subject: self, action: action, metadata: metadata, **publish_options)
    end

    def soft_delete
      super
      publish_pulse_event("#{pulse_event_prefix}.deleted") if pulse_event_prefix
    end

    def restore
      super
      publish_pulse_event("#{pulse_event_prefix}.restored") if pulse_event_prefix
    end

    private

    def create_pulse_subscribable
      Pulse::Subscribable.find_or_create_by!(subscribable: self)
    end

    def publish_pulse_created_event
      publish_pulse_event("#{pulse_event_prefix}.created")
      subscribe(Pulse::Current.user)
    end

    def publish_pulse_updated_event
      return if (saved_changes.keys - pulse_ignored_columns).empty?

      publish_pulse_event("#{pulse_event_prefix}.updated")
    end
  end
end
