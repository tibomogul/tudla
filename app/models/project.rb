class Project < ApplicationRecord
  include ActionView::RecordIdentifier # for dom_id
  has_paper_trail

  has_many :scopes
  has_many :tasks
  has_many :unscoped_tasks, -> { where(scope_id: nil) }, class_name: "Task"
  has_many :user_party_roles, as: :party
  has_many :users, through: :user_party_roles
  belongs_to :team, optional: true

  has_one :subscribable, as: :subscribable, touch: true, dependent: :destroy
  has_one :reportable, as: :reportable, dependent: :destroy
  has_many :reports, through: :reportable

  after_create :create_subscribable_record
  has_one :attachable, as: :attachable, dependent: :destroy
  has_many :attachments, through: :attachable
  has_one :notable, as: :notable, dependent: :destroy
  has_many :notes, through: :notable
  has_one :linkable, as: :linkable, dependent: :destroy
  has_many :links, through: :linkable

  has_many :project_risk_transitions, autosave: false

  # Include Statesman adapter (now compatible without default_scope)
  include Statesman::Adapters::ActiveRecordQueries[
    transition_class: ProjectRiskTransition,
    initial_state: :green
  ]

  # Include soft delete
  include SoftDeletable

  after_commit :broadcast_project_update, if: :persisted?

  def risk_state_machine
    @risk_state_machine ||= ProjectRiskStateMachine.new(self, transition_class: ProjectRiskTransition,
                                                              association_name: :project_risk_transitions,
                                                              initial_transition: true)
  end

  def risk_current_state
    risk_state || risk_state_machine.current_state
  end

  def time_in_current_risk_state
    last_transition = project_risk_transitions.order(:sort_key).last
    return nil unless last_transition

    Time.current - last_transition.created_at
  end

  # Get the organization from the project's team
  def organization
    team&.organization
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

  private

  def create_subscribable_record
    Subscribable.create!(subscribable: self)
  end

  def broadcast_project_update
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)
    broadcast_replace_to "projects", partial: "projects/project", locals: { project: self }, target: dom_id(self)
  rescue => e
    Rails.logger.error("Failed to broadcast project update: #{e.message}")
  end
end
