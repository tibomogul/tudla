class Attachable < ApplicationRecord
  delegated_type :attachable, types: %w[Project Scope Task Team Organization]

  # Attachment is SoftDeletable: #destroy only sets deleted_at. A plain
  # `dependent: :destroy` would therefore leave the rows in place while this
  # (hard-deletable) record is removed, orphaning them against the
  # attachments→attachables FK (PG::ForeignKeyViolation). Even #destroy! does not
  # help, because ActiveRecord::Persistence#destroy! delegates to #destroy, which
  # SoftDeletable overrides — so it soft-deletes too. We must genuinely remove the
  # rows: purge the Active Storage blob, then #delete the row (a direct DELETE that
  # bypasses the SoftDeletable override). Runs in the destroy transaction, before
  # this row goes, so no FK orphan remains.
  has_many :attachments
  before_destroy :purge_and_delete_attachments

  private

  def purge_and_delete_attachments
    attachments.find_each do |attachment|
      attachment.file.purge if attachment.file.attached?
      attachment.delete
    end
  end
end
