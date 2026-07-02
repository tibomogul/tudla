module Pulse
  # Delegated-type container marking a host record (Project/Scope/Task — see
  # config/initializers/pulse.rb) as something users can subscribe to.
  class Subscribable < ApplicationRecord
    delegated_type :subscribable, types: Pulse.config.subscribable_types

    has_many :subscriptions, class_name: "Pulse::Subscription", dependent: :destroy
    has_many :users, through: :subscriptions

    has_many :events, class_name: "Pulse::Event", dependent: :destroy
    has_many :notifications, through: :events

    def self.policy_class
      SubscribablePolicy
    end
  end
end
