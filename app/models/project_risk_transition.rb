class ProjectRiskTransition < ApplicationRecord
  belongs_to :project, inverse_of: :project_risk_transitions

  after_destroy :update_most_recent, if: :most_recent?

  after_commit :broadcast_transition, if: :persisted?

  private

  def broadcast_transition
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)
    broadcast_append_to "project_#{project.id}_risk_history",
      partial: "projects/risk_transition",
      locals: { transition: self },
      target: "project_#{project.id}_risk_history_timeline"
  rescue => e
    Rails.logger.error("Failed to broadcast project risk transition: #{e.message}")
  end

  def update_most_recent
    last_transition = project.project_risk_transitions.order(:sort_key).last
    return unless last_transition.present?
    last_transition.update_column(:most_recent, true)
  end
end
