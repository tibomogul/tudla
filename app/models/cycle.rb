class Cycle < ApplicationRecord
  include ActionView::RecordIdentifier
  has_paper_trail

  belongs_to :organization
  has_many :projects

  has_one :notable, as: :notable, dependent: :destroy
  has_many :notes, through: :notable
  has_one :linkable, as: :linkable, dependent: :destroy
  has_many :links, through: :linkable
  has_one :attachable, as: :attachable, dependent: :destroy
  has_many :attachments, through: :attachable

  has_many :cycle_transitions, autosave: false

  # Include Statesman adapter (now compatible without default_scope)
  include Statesman::Adapters::ActiveRecordQueries[
    transition_class: CycleTransition,
    initial_state: :shaping
  ]

  # Include soft delete
  include SoftDeletable

  after_commit :broadcast_cycle_update, if: :persisted?

  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date

  def state_machine
    @state_machine ||= CycleStateMachine.new(self, transition_class: CycleTransition,
      association_name: :cycle_transitions,
      initial_transition: true)
  end

  def current_state
    status || state_machine.current_state
  end

  # Returns progress as a percentage (0-100)
  def progress_percentage
    return 0 if start_date.nil? || end_date.nil?
    return 0 if Date.current < start_date
    return 100 if Date.current >= end_date

    total_days = (end_date - start_date).to_f
    return 0 if total_days <= 0

    elapsed_days = (Date.current - start_date).to_f
    (elapsed_days / total_days * 100).clamp(0, 100)
  end

  # Build phase: from start_date until 2 weeks before end_date
  def build_phase?
    return false unless active?

    Date.current >= start_date && Date.current < cooldown_start_date
  end

  # Cooldown phase: last 2 weeks of the cycle
  def cooldown_phase?
    return false unless active?

    Date.current >= cooldown_start_date && Date.current <= end_date
  end

  # The date when cooldown begins (2 weeks before end)
  def cooldown_start_date
    end_date - 2.weeks
  end

  # Is this cycle currently in the active state?
  def active?
    current_state == "active"
  end

  # Days remaining in the cycle
  def days_remaining
    return 0 if end_date.nil? || Date.current >= end_date

    (end_date - Date.current).to_i
  end

  # Circuit breaker: projects not shipped by cycle end
  def unfinished_projects
    projects.active.not_in_state(:done)
  end

  def finished_projects
    projects.active.in_state(:done)
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

  def end_date_after_start_date
    return unless start_date.present? && end_date.present?

    if end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def broadcast_cycle_update
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)
    broadcast_replace_to "cycles", partial: "cycles/cycle", locals: { cycle: self }, target: dom_id(self)
  rescue => e
    Rails.logger.error("Failed to broadcast cycle update: #{e.message}")
  end
end
