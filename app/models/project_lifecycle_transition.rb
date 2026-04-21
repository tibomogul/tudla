# Audit trail of project lifecycle transitions (active/done/archived).
# Rows are queryable directly for history/reporting. A dedicated history UI is
# intentionally deferred — mirror `ProjectsController#risk_history` and
# `app/views/projects/_risk_history.html.erb` if/when one is required.
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
