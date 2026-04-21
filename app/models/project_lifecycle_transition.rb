class ProjectLifecycleTransition < ApplicationRecord
  belongs_to :project, inverse_of: :project_lifecycle_transitions

  after_destroy :update_most_recent, if: :most_recent?

  private

  def update_most_recent
    last_transition = project.project_lifecycle_transitions.order(:sort_key).last
    return unless last_transition.present?
    last_transition.update_column(:most_recent, true)
  end
end
