class Note < ApplicationRecord
  include SoftDeletable
  has_paper_trail
  belongs_to :notable
  belongs_to :user

  belongs_to :last_editor, class_name: "User", optional: true

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

  private

  # PaperTrail still owns the full history; this column is just a denormalized
  # cache so list rendering doesn't have to materialize every version row.
  def assign_last_editor
    actor_id = PaperTrail.request.whodunnit.presence
    if new_record?
      self.last_editor_id ||= actor_id || user_id
    elsif actor_id
      self.last_editor_id = actor_id
    end
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
