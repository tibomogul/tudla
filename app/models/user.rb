class User < ApplicationRecord
  include SoftDeletable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :confirmable, :lockable, :invitable,
         :omniauthable, omniauth_providers: [ :google_oauth2, :microsoft_graph ]

  has_many :user_party_roles
  has_many :api_tokens, dependent: :destroy
  has_many :pitch_co_authors, dependent: :destroy

  has_many :subscriptions
  has_many :subscribables, through: :subscriptions

  has_many :notifications

  def display_name
    preferred_name.presence || username.presence || email
  end

  # Organizations the user can access via any role (org, team, OR project). Caches
  # full AR objects (not just IDs) to avoid an extra query on every page load.
  # Trade-off: if an Organization name changes or is soft-deleted, this serves stale
  # data until the next UserPartyRole change busts the cache. Acceptable because
  # org-level mutations are rare and the cached set is small (typically 1-5 orgs per
  # user). The queries inside the block only run on cache miss.
  #
  # Shares #organization_ids(via:) with #member_organization_ids — the only
  # difference is that access counts project-only roles and membership does not.
  def accessible_organizations
    Rails.cache.fetch(organizations_cache_key) do
      Organization.active.where(id: organization_ids(via: :access)).order(:name).to_a
    end
  end

  # IDs of organizations the user belongs to via a DIRECT organization role or a
  # TEAM role. Unlike #accessible_organizations, a project-only role does NOT
  # count — project membership does not imply membership in the project's
  # organization. Used for pitch visibility. Only IDs are cached (every caller
  # needs just IDs), which keeps the entry small and avoids the stale-attribute
  # risk of caching AR objects. Busted by UserPartyRole and Organization hooks,
  # plus Team org-change/soft-delete/restore and Organization soft-delete/restore
  # hooks. See #organization_ids for the shared lookup.
  def member_organization_ids
    Rails.cache.fetch(member_organization_ids_cache_key) do
      organization_ids(via: :membership)
    end
  end

  # Loads the Organization records for #member_organization_ids on demand. Kept
  # for callers that need full objects; the policy hot path uses the IDs directly.
  def member_organizations
    Organization.active.where(id: member_organization_ids).order(:name).to_a
  end

  def organizations_cache_key
    "user/#{id}/accessible_organizations"
  end

  def member_organization_ids_cache_key
    "user/#{id}/member_organization_ids"
  end

  def bust_organizations_cache
    Rails.cache.delete(organizations_cache_key)
    Rails.cache.delete(member_organization_ids_cache_key)
  end

  # Soft-delete bypasses destroy callbacks, so the dependent: :destroy on
  # pitch_co_authors won't fire. Prune the join rows explicitly here so a
  # removed user immediately loses co-authorship (and can't silently regain it
  # via the active-scoped association on restore). Each destroy is PaperTrail-audited.
  def soft_delete
    pitch_co_authors.find_each(&:destroy)
    super
  end

  # Get all teams where user can create projects
  # This includes:
  # - Teams where user is admin
  # - All teams in organizations where user is admin
  def teams_for_project_creation
    # Teams where user has admin role
    admin_team_ids = user_party_roles
      .where(party_type: "Team", role: "admin")
      .pluck(:party_id)

    # Organizations where user has admin role
    admin_org_ids = user_party_roles
      .where(party_type: "Organization", role: "admin")
      .pluck(:party_id)

    # Get all teams in those organizations
    org_team_ids = Team.where(organization_id: admin_org_ids).pluck(:id)

    # Combine and get unique team IDs
    team_ids = (admin_team_ids + org_team_ids).uniq

    Team.where(id: team_ids).order(:name)
  end

  def self.from_omniauth(access_token)
    data = access_token.info
    user = User.where(email: data["email"]).first

    unless user
      if ENV["NEW_OAUTH_USER_STRATEGY"] == "CREATE"
        user = User.create(email: data["email"],
          password: Devise.friendly_token[0, 20]
        )
      end
    end
    user
  end

  private

  # Single source of truth for "which organizations does this user belong to",
  # parameterized by which role paths count:
  #   :membership — a direct organization role or a team role only. A project-only
  #                 role does NOT make you a member of the project's org. (pitch
  #                 visibility)
  #   :access     — :membership PLUS project roles. (general app access)
  # Roles on soft-deleted teams/projects never count (.active), and the result is
  # filtered to Organization.active. Returns a de-duplicated array of org ids. The
  # two public callers cache the two shapes under distinct keys, both invalidated
  # together by #bust_organizations_cache.
  def organization_ids(via:)
    org_ids = user_party_roles.where(party_type: "Organization").pluck(:party_id)

    team_party_ids = user_party_roles.where(party_type: "Team").pluck(:party_id)
    all_ids = org_ids + Team.active.where(id: team_party_ids).pluck(:organization_id)

    if via == :access
      project_party_ids = user_party_roles.where(party_type: "Project").pluck(:party_id)
      project_team_ids = Project.active.where(id: project_party_ids).pluck(:team_id)
      all_ids += Team.active.where(id: project_team_ids).pluck(:organization_id)
    end

    Organization.active.where(id: all_ids.uniq).pluck(:id)
  end
end
