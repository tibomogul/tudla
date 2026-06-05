class Team < ApplicationRecord
  include SoftDeletable
  belongs_to :organization
  has_many :projects
  has_many :user_party_roles, as: :party
  has_many :users, through: :user_party_roles
  has_one :reportable, as: :reportable, dependent: :destroy
  has_many :reports, through: :reportable
  has_one :attachable, as: :attachable, dependent: :destroy
  has_many :attachments, through: :attachable
  has_one :notable, as: :notable, dependent: :destroy
  has_many :notes, through: :notable
  has_one :linkable, as: :linkable, dependent: :destroy
  has_many :links, through: :linkable

  # A team role is one of the paths into User#member_organizations, so changing
  # which org a team belongs to invalidates that cache for the team's members.
  after_update :bust_member_caches, if: :saved_change_to_organization_id?

  # soft_delete uses update_column, which bypasses after_update — so bust the
  # cache explicitly here (mirrors User#soft_delete). A soft-deleted team drops
  # out of member_organizations' Team.active filter, so members may lose access.
  def soft_delete
    affected = team_role_user_ids
    super
    User.where(id: affected).find_each(&:bust_organizations_cache)
  end

  # restore also uses update_column and bypasses after_update — bust explicitly
  # so members regain member_organizations access (mirrors #soft_delete). Role
  # rows are untouched by restore, so the affected set is the same as today's.
  def restore
    super
    User.where(id: team_role_user_ids).find_each(&:bust_organizations_cache)
  end

  private

  def bust_member_caches
    User.where(id: team_role_user_ids).find_each(&:bust_organizations_cache)
  end

  # Only users with a role ON this team derive org membership from it; project-only
  # roles under this team are excluded from member_organizations.
  def team_role_user_ids
    UserPartyRole.where(party_type: "Team", party_id: id).pluck(:user_id)
  end
end
