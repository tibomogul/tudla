class ApiToken < ApplicationRecord
  include SoftDeletable
  belongs_to :user

  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  # Active tokens: not revoked (active=true), not expired, and not soft-deleted
  # Overrides SoftDeletable's active scope to include revocation and expiry checks
  scope :active, -> { 
    where(deleted_at: nil)
      .where(active: true)
      .where("expires_at IS NULL OR expires_at > ?", Time.current) 
  }
  
  # Additional scopes for different states
  scope :revoked, -> { where(active: false) }
  scope :not_deleted, -> { where(deleted_at: nil) }  # Alias for SoftDeletable's active scope

  def self.authenticate(token_string)
    return nil if token_string.blank?

    token = active.find_by(token: token_string)
    return nil unless token

    token.touch(:last_used_at)
    token.user
  end

  def expired?
    return false if expires_at.nil?
    expires_at < Time.current
  end

  def revoke!
    update!(active: false)
  end

  # Override destroy to revoke AND soft delete the token
  # A soft-deleted token is automatically revoked
  def destroy
    transaction do
      update_column(:active, false) unless deleted?
      super  # Calls SoftDeletable's destroy which sets deleted_at
    end
  end

  private

  def generate_token
    self.token ||= SecureRandom.hex(32)
  end
end
