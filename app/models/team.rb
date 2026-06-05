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
  # Any member who loses org membership as a result must also lose co-authorship
  # of that org's pitches (membership is a precondition); bust each cache BEFORE
  # the prune so prune_orphaned_for rechecks against fresh membership.
  def soft_delete
    affected = team_role_user_ids
    org_id = organization_id
    super
    User.where(id: affected).find_each do |member|
      member.bust_organizations_cache
      PitchCoAuthor.prune_orphaned_for(member, org_id)
    end
  end

  # restore also uses update_column and bypasses after_update — bust explicitly
  # so members regain member_organizations access (mirrors #soft_delete). Role
  # rows are untouched by restore, so the affected set is the same as today's.
  def restore
    super
    User.where(id: team_role_user_ids).find_each(&:bust_organizations_cache)
  end

  private

  # NOTE: this busts only users with a role ON this team. A project-only role
  # under this team also derives accessible_organizations from this team's
  # organization_id, so reparenting the team leaves those users'
  # accessible_organizations cache stale until their next role change. They are
  # intentionally excluded from member_organizations (project roles don't confer
  # org membership), so the membership path — the one that gates pitches — is
  # correct; only the broader access cache has this known, low-impact gap.
  def bust_member_caches
    User.where(id: team_role_user_ids).find_each(&:bust_organizations_cache)
  end

  # Only users with a role ON this team derive org membership from it; project-only
  # roles under this team are excluded from member_organizations.
  def team_role_user_ids
    UserPartyRole.where(party_type: "Team", party_id: id).pluck(:user_id)
  end
end
