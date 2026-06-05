class PitchPolicy < ApplicationPolicy
  attr_reader :user, :pitch

  def initialize(user, pitch)
    @user = user
    @pitch = pitch
  end

  def index?
    true
  end

  def show?
    is_author? || user_is_organization_member?
  end

  def create?
    if pitch.organization.nil?
      # For new pitches without org set, check if user is member of any org
      UserPartyRole.where(user: user, party_type: "Organization").exists?
    else
      user_is_organization_member?
    end
  end

  def new?
    create?
  end

  def update?
    (is_author? && draft?) || user_is_organization_admin?
  end

  def edit?
    update?
  end

  def destroy?
    is_author? && draft?
  end

  def submit?
    is_author? && draft?
  end

  def bet?
    user_is_organization_admin?
  end

  def reject?
    user_is_organization_admin?
  end

  # Org admins may change authorship at any status (so a mistaken grant can be
  # fixed post-submission). A non-admin creator may only do so while the pitch
  # is still a draft. Co-authors can edit/submit/delete the pitch, but cannot
  # alter who the authors are.
  def manage_co_authors?
    user_is_organization_admin? || (is_creator? && draft?)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # Pitches are visible to users who belong to the pitch's organization via a
    # direct org role or a team role (NOT a project-only role). member_organizations
    # is the cached reverse lookup of that membership, invalidated by
    # UserPartyRole's after_commit hook.
    def resolve
      return scope.none unless user

      org_ids = user.member_organizations.map(&:id)
      scope
        .active
        .where(organization_id: org_ids)
    end

    private

    attr_reader :user, :scope
  end

  private

  # The policy may be instantiated with the Pitch class (e.g. authorize Pitch),
  # in which case there is no concrete record to derive an organization from.
  def org
    return @org if defined?(@org)
    @org = pitch.is_a?(Pitch) ? pitch.organization : nil
  end

  def is_creator?
    return @is_creator if defined?(@is_creator)
    @is_creator = pitch.is_a?(Pitch) && pitch.user_id.present? && pitch.user_id == user&.id
  end

  def is_co_author?
    return @is_co_author if defined?(@is_co_author)
    @is_co_author = user.present? && pitch.is_a?(Pitch) && pitch.co_author_ids.include?(user.id)
  end

  def is_author?
    is_creator? || is_co_author?
  end

  def draft?
    pitch.current_state == "draft"
  end

  # Membership via a direct org role or a team role (not a project-only role)
  # within the pitch's organization. Shares its definition with Scope#resolve.
  def user_is_organization_member?
    return @user_is_organization_member if defined?(@user_is_organization_member)
    @user_is_organization_member = org.present? && user.present? &&
      user.member_organizations.any? { |o| o.id == org.id }
  end

  # Admin remains an explicit organization-level role, not hierarchy-derived.
  def organization_role
    return @organization_role if defined?(@organization_role)
    @organization_role = if org && user
      UserPartyRole.where(user: user, party: org).first&.role
    end
  end

  def user_is_organization_admin?
    organization_role == "admin"
  end
end
