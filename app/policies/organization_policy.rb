class OrganizationPolicy < ApplicationPolicy
  attr_reader :user, :organization, :organization_role

  def initialize(user, organization)
    @user = user
    @organization = organization
    if organization
      @organization_role = UserPartyRole.where(user: user, party: organization).first&.role
    end
  end

  def index?
    true # anyone can see the index, but their view is scoped
  end

  def show?
    user_is_organization_member?
  end

  def create?
    false # only an admin can create organizations, now we do by console
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
    false # nobody can destroy organizations
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
      scope.active.where(id: org_ids)
    end

    private

    attr_reader :user, :scope
  end

  protected

  def user_is_organization_member?
    organization_role.present?
  end

  def user_is_organization_admin?
    organization_role == "admin"
  end
end
