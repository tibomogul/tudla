class UserPartyRole < ApplicationRecord
  VALID_ROLES = %w[admin member].freeze

  belongs_to :user
  belongs_to :party, polymorphic: true

  validates :role, inclusion: { in: VALID_ROLES }

  after_commit :bust_user_organizations_cache

  private

  def bust_user_organizations_cache
    user.bust_organizations_cache
  end
end
