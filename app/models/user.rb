class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :confirmable, :lockable,
         :omniauthable, omniauth_providers: [ :google_oauth2, :microsoft_graph ]

  has_many :user_party_roles
  has_many :api_tokens, dependent: :destroy

  has_many :subscriptions
  has_many :subscribables, through: :subscriptions

  has_many :notifications

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
