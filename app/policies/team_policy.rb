class TeamPolicy < ApplicationPolicy
  attr_reader :user, :team, :team_role, :organization_role

  def initialize(user, team)
    @user = user
    @team = team
    if team.instance_of? Team
      @team_role = UserPartyRole.where(user: user, party: team).first&.role
      @organization_role = UserPartyRole.where(user: user, party: team.organization).first&.role
    end
  end

  def index?
    true # anybody can see the index, but their list is scoped
  end

  def show?
    user_is_team_member? || user_is_organization_member?
  end

  def create?
    false # can only be done by an admin
  end

  def new?
    create?
  end

  def update?
    user_is_team_admin?
  end

  def edit?
    update?
  end

  def destroy?
    false # can only be done by an admin
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
      team_ids = Team.active.where(organization_id: org_ids).pluck(:id)
      team_ids |= UserPartyRole
        .where(user: user, party_type: "Team")
        .pluck(:party_id)
      scope.active.where(id: team_ids)
    end

    private

    attr_reader :user, :scope
  end

  private

  def user_is_team_member?
    team_role.present?
  end

  def user_is_team_admin?
    team_role == "admin"
  end

  def user_is_organization_member?
    organization_role.present?
  end

  def user_is_organization_admin?
    organization_role == "admin"
  end
end
