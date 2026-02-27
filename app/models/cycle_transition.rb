class CycleTransition < ApplicationRecord
  belongs_to :cycle, inverse_of: :cycle_transitions

  after_destroy :update_most_recent, if: :most_recent?

  after_commit :broadcast_transition, if: :persisted?

  private

  def broadcast_transition
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)
    broadcast_append_to "cycle_#{cycle.id}_history",
      partial: "cycles/transition",
      locals: { transition: self },
      target: "cycle_#{cycle.id}_history_timeline"
  rescue => e
    Rails.logger.error("Failed to broadcast cycle transition: #{e.message}")
  end

  def update_most_recent
    last_transition = cycle.cycle_transitions.order(:sort_key).last
    return unless last_transition.present?
    last_transition.update_column(:most_recent, true)
  end
end
