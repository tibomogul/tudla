class Scope < ApplicationRecord
  include SoftDeletable
  has_paper_trail skip: [ :project_position ]
  belongs_to :project
  has_many :tasks
  has_many :done_tasks, -> { where(done: true) }, class_name: "Task"

  has_one :subscribable, as: :subscribable, touch: true
  has_one :attachable, as: :attachable, dependent: :destroy
  has_many :attachments, through: :attachable
  has_one :notable, as: :notable, dependent: :destroy
  has_many :notes, through: :notable
  has_one :linkable, as: :linkable, dependent: :destroy
  has_many :links, through: :linkable

  def percent_done
    total = tasks.count
    return 0 if total.zero?

    done_count = tasks
      .joins(:task_transitions)
      .merge(TaskTransition.where(most_recent: true, to_state: "done"))
      .distinct
      .count(:id)

    ((done_count.to_f / total) * 100).round
  end
end
