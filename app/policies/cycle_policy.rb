class CyclePolicy < ApplicationPolicy
  attr_reader :user, :cycle, :organization_role

  def initialize(user, cycle)
    @user = user
    @cycle = cycle
    if cycle.class.name == "Cycle" && cycle.organization.present?
      @organization_role = UserPartyRole.where(user: user, party: cycle.organization).first&.role
    end
  end

  def index?
    true
  end

  def show?
    user_is_organization_member?
  end

  def create?
    if cycle.organization.nil?
      # For new cycles without org set, check if user is admin on any org
      UserPartyRole.where(user: user, role: "admin", party_type: "Organization").exists?
    else
      user_is_organization_admin?
    end
  end

  def new?
    create?
  end

  def update?
    user_is_organization_admin?
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def transition?
    user_is_organization_admin?
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

      scope.active.where(organization_id: org_ids)
    end

    private

    attr_reader :user, :scope
  end

  private

  def user_is_organization_member?
    organization_role.present?
  end

  def user_is_organization_admin?
    organization_role == "admin"
  end
end
