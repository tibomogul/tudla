module SoftDeletable
  extend ActiveSupport::Concern

  included do
    # Scopes for accessing deleted/non-deleted records
    # NOTE: No default_scope to avoid conflicts with Statesman and Rails 8 insert_all
    scope :active, -> { where(deleted_at: nil) }
    scope :with_deleted, -> { unscope(where: :deleted_at) }
    scope :only_deleted, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }
  end

  # Soft delete the record
  def soft_delete
    update_column(:deleted_at, Time.current)
  end

  # Restore a soft-deleted record
  def restore
    update_column(:deleted_at, nil)
  end

  # Check if record is soft deleted
  def deleted?
    deleted_at.present?
  end

  # Override destroy to perform soft delete instead
  def destroy
    soft_delete
  end

  # Hard delete (actually remove from database)
  def destroy!
    super
  end
end
