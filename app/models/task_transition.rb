class TaskTransition < ApplicationRecord
  belongs_to :task, inverse_of: :task_transitions

  after_destroy :update_most_recent, if: :most_recent?

  after_commit :broadcast_transition, if: :persisted?

  private

  def broadcast_transition
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)
    broadcast_append_to "task_#{task.id}_history",
      partial: "tasks/transition",
      locals: { transition: self },
      target: "task_#{task.id}_history_timeline"
  rescue => e
    Rails.logger.error("Failed to broadcast task transition: #{e.message}")
  end

  def update_most_recent
    last_transition = task.task_transitions.order(:sort_key).last
    return unless last_transition.present?
    last_transition.update_column(:most_recent, true)
  end
end
