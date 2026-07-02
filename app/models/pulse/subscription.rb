module Pulse
  class Subscription < ApplicationRecord
    belongs_to :user
    belongs_to :subscribable, class_name: "Pulse::Subscribable"

    validates :user_id, uniqueness: { scope: :subscribable_id }

    def self.policy_class
      SubscriptionPolicy
    end
  end
end
