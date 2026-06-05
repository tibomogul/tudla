class UserPartyRole < ApplicationRecord
  VALID_ROLES = %w[admin member].freeze

  belongs_to :user
  belongs_to :party, polymorphic: true

  validates :role, inclusion: { in: VALID_ROLES }

  after_commit :bust_user_organizations_cache
  # Declared AFTER the cache bust so the membership recheck below recomputes fresh.
  after_commit :prune_orphaned_pitch_co_authorships, on: :destroy

  private

  def bust_user_organizations_cache
    user.bust_organizations_cache
  end

  # When a role is removed and the user no longer belongs to the affected org,
  # drop their co-author rows for that org's pitches — co-authorship requires
  # current membership. The cache bust above runs first (declared earlier), so
  # the membership recheck inside prune_orphaned_for sees fresh data.
  def prune_orphaned_pitch_co_authorships
    org_id = affected_organization_id
    return unless org_id

    PitchCoAuthor.prune_orphaned_for(user, org_id)
  end

  # Org and Team roles map to an organization; a Project-only role never granted
  # pitch visibility (member_organizations excludes it), so it can't orphan rows.
  def affected_organization_id
    case party_type
    when "Organization" then party_id
    when "Team"         then Team.with_deleted.find_by(id: party_id)&.organization_id
    end
  end
end
