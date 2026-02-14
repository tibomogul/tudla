class Task < ApplicationRecord
  has_paper_trail skip: [ :backlog_position, :today_position, :scope_position, :in_today ]
  include ActionView::RecordIdentifier # for dom_id

  belongs_to :project, optional: true
  belongs_to :scope, optional: true
  belongs_to :responsible_user, optional: true, class_name: "User"

  has_one :subscribable, as: :subscribable, touch: true
  has_one :attachable, as: :attachable, dependent: :destroy
  has_many :attachments, through: :attachable
  has_one :notable, as: :notable, dependent: :destroy
  has_many :notes, through: :notable
  has_one :linkable, as: :linkable, dependent: :destroy
  has_many :links, through: :linkable

  has_many :task_transitions, autosave: false

  # Include Statesman adapter (now compatible without default_scope)
  include Statesman::Adapters::ActiveRecordQueries[
    transition_class: TaskTransition,
    initial_state: :new
  ]

  # Include soft delete
  include SoftDeletable

  # Include estimate rollup caching to scopes/projects
  include EstimateCacheable

  after_commit :broadcast_task_update, if: :persisted?

  def state_machine
    @state_machine ||= TaskStateMachine.new(self, transition_class: TaskTransition,
                                                  association_name: :task_transitions,
                                                  initial_transition: true)
  end

  def current_state
    self.state || state_machine.current_state
  end

  def time_in_current_state
    last_transition = task_transitions.order(:sort_key).last
    return nil unless last_transition

    Time.current - last_transition.created_at
  end

  # Get the organization from the task's project
  def organization
    project&.team&.organization
  end

  # Get the organization's timezone or default
  def timezone
    organization&.timezone || "Australia/Brisbane"
  end

  # Format a datetime in the organization's timezone
  def format_in_timezone(datetime, format = "%d %b %H:%M")
    return nil unless datetime
    datetime.in_time_zone(timezone).strftime(format)
  end

  def assignable_users
    # here is a list of users that can be assigned to this task
    users = []
    # the reponsible_user on the task
    users << responsible_user if responsible_user
    # the members of the team the project is assigned_to
    users += project.team.users if project&.team
    # any users directly assigned to the project
    users += project.users if project

    users.uniq
  end

  private

  def broadcast_task_update
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)
    broadcast_replace_to "tasks", partial: "tasks/task", locals: { task: self }, target: dom_id(self)
  rescue => e
    Rails.logger.error("Failed to broadcast task update: #{e.message}")
  end
end
