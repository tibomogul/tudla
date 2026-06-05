class PitchPolicy < ApplicationPolicy
  attr_reader :user, :pitch, :organization_role, :is_creator, :is_co_author

  def initialize(user, pitch)
    @user = user
    @pitch = pitch
    if pitch.class.name == "Pitch" && pitch.organization.present?
      @organization_role = UserPartyRole.where(user: user, party: pitch.organization).first&.role
      @is_creator = pitch.user_id.present? && pitch.user_id == user&.id
      @is_co_author = user.present? && pitch.respond_to?(:co_author_ids) &&
        pitch.co_author_ids.include?(user.id)
    end
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

  def manage_co_authors?
    is_author? || user_is_organization_admin?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      org_ids = UserPartyRole
        .where(user: user, party_type: "Organization")
        .pluck(:party_id)

      scope
        .active
        .where(organization_id: org_ids)
    end

    private

    attr_reader :user, :scope
  end

  private

  def is_creator?
    is_creator
  end

  def is_author?
    is_creator || is_co_author
  end

  def draft?
    pitch.current_state == "draft"
  end

  def user_is_organization_member?
    organization_role.present?
  end

  def user_is_organization_admin?
    organization_role == "admin"
  end
end
