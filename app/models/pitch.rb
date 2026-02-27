class Pitch < ApplicationRecord
  include ActionView::RecordIdentifier
  has_paper_trail

  belongs_to :user
  belongs_to :organization
  has_many :projects

  has_one :notable, as: :notable, dependent: :destroy
  has_many :notes, through: :notable
  has_one :linkable, as: :linkable, dependent: :destroy
  has_many :links, through: :linkable
  has_one :attachable, as: :attachable, dependent: :destroy
  has_many :attachments, through: :attachable

  has_many :pitch_transitions, autosave: false

  # Include Statesman adapter (now compatible without default_scope)
  include Statesman::Adapters::ActiveRecordQueries[
    transition_class: PitchTransition,
    initial_state: :draft
  ]

  # Include soft delete
  include SoftDeletable

  after_commit :broadcast_pitch_update, if: :persisted?

  validates :title, presence: true
  validates :appetite, inclusion: { in: [ 2, 6 ] }

  # Draft pitches are only visible to their creator;
  # all other statuses are visible to organization members
  scope :visible_to, ->(user) {
    where(status: %w[ready_for_betting bet rejected])
      .or(where(user: user, status: "draft"))
  }

  def state_machine
    @state_machine ||= PitchStateMachine.new(self, transition_class: PitchTransition,
      association_name: :pitch_transitions,
      initial_transition: true)
  end

  def current_state
    status || state_machine.current_state
  end

  def time_in_current_state
    last_transition = pitch_transitions.order(:sort_key).last
    return nil unless last_transition

    Time.current - last_transition.created_at
  end

  # Human-readable appetite label
  def appetite_label
    case appetite
    when 2 then "Small Batch"
    when 6 then "Big Batch"
    else "#{appetite} weeks"
    end
  end

  # Check if all five ingredients are filled out
  def ingredients_complete?
    problem.present? && appetite.present? && solution.present? &&
      rabbit_holes.present? && no_gos.present?
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

  def broadcast_pitch_update
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)
    broadcast_replace_to "pitches", partial: "pitches/pitch", locals: { pitch: self }, target: dom_id(self)
  rescue => e
    Rails.logger.error("Failed to broadcast pitch update: #{e.message}")
  end
end
