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

  has_many :subscriptions
  has_many :subscribables, through: :subscriptions

  has_many :notifications

  # Caches full AR objects (not just IDs) to avoid an extra query on every page load.
  # Trade-off: if an Organization name changes or is soft-deleted, this serves stale data
  # until the next UserPartyRole change busts the cache. Acceptable because org-level
  # mutations are rare and the cached set is small (typically 1-5 orgs per user).
  # The multiple queries inside the block only run on cache miss.
  def accessible_organizations
    Rails.cache.fetch(organizations_cache_key) do
      org_ids = user_party_roles
        .where(party_type: "Organization")
        .pluck(:party_id)

      team_org_ids = Team.where(
        id: user_party_roles.where(party_type: "Team").pluck(:party_id)
      ).pluck(:organization_id)

      project_team_ids = Project.where(
        id: user_party_roles.where(party_type: "Project").pluck(:party_id)
      ).pluck(:team_id)
      project_org_ids = Team.where(id: project_team_ids).pluck(:organization_id)

      all_org_ids = (org_ids + team_org_ids + project_org_ids).uniq
      Organization.active.where(id: all_org_ids).order(:name).to_a
    end
  end

  def organizations_cache_key
    "user/#{id}/accessible_organizations"
  end

  def bust_organizations_cache
    Rails.cache.delete(organizations_cache_key)
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
end
