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
    is_creator? || user_is_organization_member?
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
    return false if locked?
    (writable_author? && draft?) || user_is_organization_admin?
  end

  def edit?
    update?
  end

  # A bet pitch is a locked historical record of what was shaped and bet on. It
  # returns to ready_for_betting only by undoing the bet (not modelled), and is
  # never directly editable again. Rejected pitches go back to draft to rework;
  # ready_for_betting pitches can be pulled back to draft to keep shaping.
  def withdraw?
    return false unless pitch.current_state.in?(%w[ready_for_betting rejected])
    writable_author? || user_is_organization_admin?
  end

  def destroy?
    writable_author? && draft?
  end

  def submit?
    writable_author? && draft?
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
    return false if locked?
    user_is_organization_admin? || (is_creator? && draft? && user_is_organization_member?)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # Pitches are visible to users who belong to the pitch's organization via a
    # direct org role or a team role (NOT a project-only role). member_organization_ids
    # is the cached reverse lookup of that membership, invalidated by
    # UserPartyRole's after_commit hook.
    def resolve
      return scope.none unless user

      org_ids = user.member_organization_ids
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

  # An author — the creator or a listed co-author — who is CURRENTLY an org
  # member. Authorship grants edit/submit/delete rights only while membership
  # lasts; losing all org roles revokes them for creator and co-author alike.
  # The membership gate also guards against stale co-author join rows surviving
  # a role removal before the prune in UserPartyRole has run.
  def writable_author?
    user_is_organization_member? && (is_creator? || listed_co_author?)
  end

  # Pure membership-free check: is the user in the pitch's co-author list? The
  # org-membership gate lives in #writable_author? so both author paths share it.
  def listed_co_author?
    return @listed_co_author if defined?(@listed_co_author)
    @listed_co_author = user.present? && pitch.is_a?(Pitch) &&
      pitch.co_author_ids.include?(user.id)
  end

  def draft?
    pitch.current_state == "draft"
  end

  # Bet pitches are frozen: once converted to a project the pitch is a read-only
  # record for everyone, including org admins. This also freezes notes,
  # attachments and links, whose views key off #update?.
  def locked?
    pitch.current_state == "bet"
  end

  # Membership via a direct org role or a team role (not a project-only role)
  # within the pitch's organization. Shares its definition with Scope#resolve.
  def user_is_organization_member?
    return @user_is_organization_member if defined?(@user_is_organization_member)
    @user_is_organization_member = org.present? && user.present? &&
      user.member_organization_ids.include?(org.id)
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
