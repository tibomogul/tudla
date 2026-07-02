module Pulse
  # A domain event published against a subscribable. Actions follow Stripe-style
  # "<object>.<past_tense_verb>" dot notation and map 1:1 to i18n keys under
  # pulse.events.*. Metadata carries denormalized display data (subject_name,
  # actor_name) captured at publish time so notification text survives later
  # rename or deletion of the subject.
  class Event < ApplicationRecord
    ACTOR_TYPES = %w[user agent system].freeze

    CATALOG = %w[
      project.created project.updated project.deleted project.restored
      project.transitioned project.risk_changed
      scope.created scope.updated scope.deleted scope.restored
      task.created task.updated task.deleted task.restored
      task.transitioned task.assigned task.unassigned
      note.created
    ].freeze

    belongs_to :subscribable, class_name: "Pulse::Subscribable"
    belongs_to :user, optional: true
    has_many :notifications, class_name: "Pulse::Notification", dependent: :destroy

    validates :action, presence: true, inclusion: { in: ->(_) { CATALOG + Pulse.config.catalog_extensions } }
    validates :actor_type, inclusion: { in: ACTOR_TYPES }
    validates :user, presence: true, if: -> { actor_type == "user" }

    after_create_commit :enqueue_fanout

    def actor_name
      user&.display_name || actor_label.presence || "System"
    end

    def self.policy_class
      EventPolicy
    end

    private

    def enqueue_fanout
      Pulse::FanoutJob.perform_later(id)
    end
  end
end
