class PitchTransition < ApplicationRecord
  belongs_to :pitch, inverse_of: :pitch_transitions

  after_destroy :update_most_recent, if: :most_recent?

  after_commit :broadcast_transition, if: :persisted?

  private

  def broadcast_transition
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)
    broadcast_append_to "pitch_#{pitch.id}_history",
      partial: "pitches/transition",
      locals: { transition: self },
      target: "pitch_#{pitch.id}_history_timeline"
  rescue => e
    Rails.logger.error("Failed to broadcast pitch transition: #{e.message}")
  end

  def update_most_recent
    last_transition = pitch.pitch_transitions.order(:sort_key).last
    return unless last_transition.present?
    last_transition.update_column(:most_recent, true)
  end
end
