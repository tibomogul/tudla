class Note < ApplicationRecord
  include SoftDeletable
  has_paper_trail
  belongs_to :notable
  belongs_to :user

  validates :content, presence: true

  # Broadcasts updates to the notes list
  after_commit :broadcast_note_update, on: [ :create, :update, :destroy ]

  private

  def broadcast_note_update
    # Broadcast to the parent record's notes stream
    return unless notable&.notable
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)

    record = notable.notable

    broadcast_replace_to(
      "#{record.class.name.underscore}_#{record.id}_notes",
      target: "#{record.class.name.underscore}_#{record.id}_notes",
      partial: "shared/notes_list",
      locals: { notes: notable.notes.order(created_at: :desc), show_header: false }
    )
  rescue => e
    Rails.logger.error("Failed to broadcast note update: #{e.message}")
  end
end
