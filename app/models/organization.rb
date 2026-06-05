class Organization < ApplicationRecord
  include SoftDeletable

  encrypts :llm_api_key

  has_many :user_party_roles, as: :party
  has_many :teams
  has_one :attachable, as: :attachable, dependent: :destroy
  has_many :attachments, through: :attachable
  has_one :notable, as: :notable, dependent: :destroy
  has_many :notes, through: :notable
  has_one :linkable, as: :linkable, dependent: :destroy
  has_many :links, through: :linkable

  validate :llm_settings_completeness
  validate :llm_api_base_format
  after_update :bust_members_organizations_cache

  def llm_configured?
    read_attribute_before_type_cast(:llm_api_key).present? && llm_api_base.present? && llm_model.present?
  end

  # soft_delete/restore use update_column, which bypasses the after_update hook
  # above — so bust members' caches explicitly (mirrors Team#soft_delete). On
  # soft-delete the org drops out of member_organizations' Organization.active
  # filter, so capture the member set BEFORE super while it is still resolvable.
  def soft_delete
    affected = members.to_a
    super
    affected.each(&:bust_organizations_cache)
  end

  def restore
    super
    bust_members_organizations_cache
  end

  # Returns the set of IDs for entities in this organization's hierarchy.
  # Used to efficiently check membership and filter roles without N+1 queries.
  # Pass include_projects: false to scope to direct org + team roles only
  # (e.g. pitch membership, which excludes project-only roles).
  def hierarchy_ids(include_projects: true)
    team_ids = teams.active.pluck(:id)
    project_ids = include_projects ? Project.active.where(team_id: team_ids).pluck(:id) : []
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
  def members(hierarchy: nil, include_projects: true)
    h = hierarchy || hierarchy_ids(include_projects: include_projects)
    user_ids = hierarchy_roles(hierarchy: h).distinct.pluck(:user_id)
    User.active.where(id: user_ids)
  end

  private

  def bust_members_organizations_cache
    members.find_each(&:bust_organizations_cache)
  end

  def llm_settings_completeness
    fields = [ read_attribute_before_type_cast(:llm_api_key), llm_api_base, llm_model ]
    filled = fields.select(&:present?)
    return if filled.empty? || filled.size == fields.size

    errors.add(:llm_api_base, "is required when other LLM settings are provided") if llm_api_base.blank?
    errors.add(:llm_model, "is required when other LLM settings are provided") if llm_model.blank?
    errors.add(:llm_api_key, "is required when other LLM settings are provided") if read_attribute_before_type_cast(:llm_api_key).blank?
  end

  def llm_api_base_format
    return if llm_api_base.blank?

    uri = URI.parse(llm_api_base)
    errors.add(:llm_api_base, "must be a valid HTTP(S) URL") unless uri.is_a?(URI::HTTP)
  rescue URI::InvalidURIError
    errors.add(:llm_api_base, "must be a valid HTTP(S) URL")
  end
end
