class Organization < ApplicationRecord
  include SoftDeletable
  has_many :user_party_roles, as: :party
  has_many :teams
  has_one :attachable, as: :attachable, dependent: :destroy
  has_many :attachments, through: :attachable
  has_one :notable, as: :notable, dependent: :destroy
  has_many :notes, through: :notable
  has_one :linkable, as: :linkable, dependent: :destroy
  has_many :links, through: :linkable

  # Returns the set of IDs for entities in this organization's hierarchy.
  # Used to efficiently check membership and filter roles without N+1 queries.
  def hierarchy_ids
    team_ids = teams.active.pluck(:id)
    project_ids = Project.active.where(team_id: team_ids).pluck(:id)
    { org_id: id, team_ids: team_ids.to_set, project_ids: project_ids.to_set }
  end

  # Returns a UserPartyRole scope filtered to roles within this organization's hierarchy.
  # Accepts an optional pre-computed hierarchy hash to avoid redundant queries.
  def hierarchy_roles(hierarchy: nil)
    h = hierarchy || hierarchy_ids
    conditions = UserPartyRole.where(party_type: "Organization", party_id: h[:org_id])
    conditions = conditions.or(UserPartyRole.where(party_type: "Team", party_id: h[:team_ids].to_a)) if h[:team_ids].present?
    conditions = conditions.or(UserPartyRole.where(party_type: "Project", party_id: h[:project_ids].to_a)) if h[:project_ids].present?
    conditions
  end

  # Returns whether the given user has any role within this organization's hierarchy
  # (direct org role, team role, or project role).
  def member?(user, hierarchy: nil)
    hierarchy_roles(hierarchy: hierarchy).where(user: user).exists?
  end

  # Returns an ActiveRecord relation of active users who have any role
  # within this organization's hierarchy.
  def members(hierarchy: nil)
    user_ids = hierarchy_roles(hierarchy: hierarchy).distinct.pluck(:user_id)
    User.active.where(id: user_ids)
  end
end
