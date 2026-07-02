class Scope < ApplicationRecord
  include SoftDeletable
  include ContentDuplicatable
  # Publish Pulse events (after SoftDeletable so soft_delete/restore overrides
  # can call super)
  include Pulse::Publishable
  publishes_pulse_events prefix: :scope,
    ignore: %w[cached_actual_manhours cached_ai_assisted_estimate cached_unassisted_estimate
               deleted_at project_position project_lifecycle_state]
  has_paper_trail skip: [ :project_position ]
  belongs_to :project
  has_many :tasks
  has_many :done_tasks, -> { active.where(done: true) }, class_name: "Task"

  has_one :subscribable, as: :subscribable, touch: true, dependent: :destroy, class_name: "Pulse::Subscribable"
  has_one :attachable, as: :attachable, dependent: :destroy
  has_many :attachments, through: :attachable
  has_one :notable, as: :notable, dependent: :destroy
  has_many :notes, through: :notable
  has_one :linkable, as: :linkable, dependent: :destroy
  has_many :links, through: :linkable

  before_create :inherit_lifecycle_from_project

  def read_only?
    project_lifecycle_state.to_s != "active"
  end

  def percent_done
    total = tasks.active.count
    return 0 if total.zero?

    done_count = tasks.active
      .joins(:task_transitions)
      .merge(TaskTransition.where(most_recent: true, to_state: "done"))
      .distinct
      .count(:id)

    ((done_count.to_f / total) * 100).round
  end

  private

  def inherit_lifecycle_from_project
    self.project_lifecycle_state = project.lifecycle_state if project
  end
end
