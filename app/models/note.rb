class Note < ApplicationRecord
  include SoftDeletable
  has_paper_trail
  belongs_to :notable
  belongs_to :user

  belongs_to :last_editor, class_name: "User", optional: true

  # Callers may set `current_editor` explicitly (e.g. service objects that don't
  # run inside a controller request) instead of relying on PaperTrail's
  # thread-local whodunnit.
  attr_accessor :current_editor

  validates :content, presence: true

  before_save :assign_last_editor

  # Eager-loads the associations needed by `last_editor`'s display so it can
  # be called in lists without triggering a per-row query.
  scope :with_last_editor, -> { includes(:user, :last_editor) }

  # Resolves the actual parent record (Project, Scope, Task, …) behind the
  # delegated-types `Notable` row.
  def parent_record
    notable&.resolve_record
  end

  # Broadcasts updates to the notes list
  after_commit :broadcast_note_update, on: [ :create, :update, :destroy ]

  # Notes have no subscribable of their own — note.created is published
  # against the parent (Project/Scope/Task). Team/Organization notes are
  # skipped because those parents don't include Pulse::Publishable.
  after_create :publish_pulse_note_event

  private

  # PaperTrail still owns the full history; this column is just a denormalized
  # cache so list rendering doesn't have to materialize every version row.
  # Only bumped when the note's content/title is actually edited — saves that
  # only touch other columns leave `last_editor_id` alone.
  def assign_last_editor
    actor_id = current_editor&.id || Integer(PaperTrail.request.whodunnit.to_s, exception: false)
    if new_record?
      self.last_editor_id ||= actor_id || user_id
    elsif actor_id && (will_save_change_to_content? || will_save_change_to_title?)
      self.last_editor_id = actor_id
    end
  end

  def publish_pulse_note_event
    parent = parent_record
    return unless parent.respond_to?(:publish_pulse_event)

    parent.publish_pulse_event("note.created", metadata: {
      "note_id" => id,
      "note_excerpt" => content.to_s.truncate(120)
    })
  end

  def broadcast_note_update
    # Broadcast to the parent record's notes stream
    return unless notable&.notable
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)

    record = notable.notable

    broadcast_replace_to(
      "#{record.class.name.underscore}_#{record.id}_notes",
      target: "#{record.class.name.underscore}_#{record.id}_notes",
      partial: "shared/notes_list",
      locals: { notes: notable.notes.active.with_last_editor.order(created_at: :desc), show_header: false, parent: record }
    )
  rescue => e
    Rails.logger.error("Failed to broadcast note update: #{e.message}")
  end
end
