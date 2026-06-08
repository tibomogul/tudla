class Pitch < ApplicationRecord
  include ActionView::RecordIdentifier
  has_paper_trail

  belongs_to :user
  belongs_to :organization
  has_many :projects

  has_many :pitch_co_authors, dependent: :destroy
  has_many :co_authors, -> { active }, through: :pitch_co_authors, source: :user

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
  validates :appetite, inclusion: { in: 1..6 }

  # Pitches the user is responsible for shaping — as creator or as a co-author.
  # Backs the "My Drafts" index filter. distinct guards against duplicate rows
  # from the co-author join when a user is both creator and (somehow) listed.
  scope :authored_by, ->(user) {
    left_outer_joins(:pitch_co_authors)
      .where("pitches.user_id = :id OR pitch_co_authors.user_id = :id", id: user.id)
      .distinct
  }

  # Pitches rejected at a specific cycle's betting table. A rejected pitch — unlike
  # a bet one — produces no project to carry the cycle link, so the cycle is stamped
  # into the rejection transition's metadata (see PitchesController#transition). The
  # jsonb @> containment query is backed by the GIN index on pitch_transitions.metadata.
  scope :rejected_in_cycle, ->(cycle) {
    where(status: "rejected").where(
      id: PitchTransition.where(to_state: "rejected")
        .where("metadata @> ?", { cycle_id: cycle.id }.to_json)
        .select(:pitch_id)
    )
  }

  # Active members of the pitch's organization eligible to be added as
  # co-authors, excluding the creator who already authors the pitch. Mirrors
  # pitch visibility: direct org members and team members only (include_projects:
  # false excludes project-only roles, matching User#member_organizations).
  def assignable_co_authors
    return User.none unless organization
    organization.members(include_projects: false).where.not(id: user_id)
  end

  # Reconciles co-authors against the given user ids, sanitized to assignable
  # members (so tampered or non-eligible ids are ignored). Operates on the
  # UNSCOPED pitch_co_authors join so rows for soft-deleted users are pruned
  # too; removals go through destroy() so PaperTrail audits each change.
  def sync_co_authors(user_ids)
    allowed = (assignable_co_authors.pluck(:id) & Array(user_ids).map(&:to_i)).to_set
    transaction do
      pitch_co_authors.where.not(user_id: allowed.to_a).find_each(&:destroy)
      existing = pitch_co_authors.reload.map(&:user_id).to_set
      (allowed - existing).each do |uid|
        # first_or_create! keeps this idempotent if a row already exists (e.g. a
        # concurrent save), so we don't trip the pitch_id/user_id unique index.
        pitch_co_authors.where(user_id: uid).first_or_create!
      end
    end
  end

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
  APPETITE_BATCHES = {
    small: { range: 1..2, label: "Small Batch" },
    medium: { range: 3..4, label: "Medium Batch" },
    big: { range: 5..6, label: "Big Batch" }
  }.freeze

  def appetite_label
    batch = APPETITE_BATCHES.values.find { |b| b[:range].cover?(appetite) }
    batch ? "#{batch[:label]} (#{appetite}w)" : "#{appetite} weeks"
  end

  def appetite_batch
    APPETITE_BATCHES.each do |key, config|
      return key if config[:range].cover?(appetite)
    end
    :small
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

  # super (SoftDeletable) uses update_column, which bypasses the
  # dependent: :destroy on pitch_co_authors — so prune the join rows explicitly,
  # honoring that intent and keeping the PaperTrail audit. Sits alongside the
  # project-link nullification, which already treats soft-delete as discarding
  # association state.
  def soft_delete
    projects.update_all(pitch_id: nil)
    pitch_co_authors.find_each(&:destroy)
    super
  end

  private

  def broadcast_pitch_update
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)
    broadcast_replace_to "pitches", partial: "pitches/pitch", locals: { pitch: self }, target: dom_id(self)
  rescue => e
    Rails.logger.error("Failed to broadcast pitch update: #{e.message}")
  end
end
