class ProjectPolicy < ApplicationPolicy
  attr_reader :user, :project, :project_role, :team_role, :organization_role

  def initialize(user, project)
    @user = user
    @project = project
    if project.instance_of? Project
      @project_role = UserPartyRole.where(user: user, party: project).first&.role
      @team_role = UserPartyRole.where(user: user, party: project.team).first&.role if project.team
      @organization_role = UserPartyRole.where(user: user, party: project.team&.organization).first&.role if project.team&.organization
    end
  end

  def index?
    true # anybody can go to the index, but the list is scoped
  end

  def show?
    user_is_project_member? || user_is_team_member? || user_is_organization_member?
  end

  def create?
    # For new projects (no team set yet), check if user has ANY admin roles
    if project.team.nil?
      # Check if user is admin on any team or organization
      UserPartyRole.where(user: user, role: "admin")
        .where(party_type: ["Team", "Organization"])
        .exists?
    else
      # For existing projects or projects with team set, check specific team/org
      user_is_team_admin? || user_is_organization_admin?
    end
  end

  def new?
    create?
  end

  def update?
    create?
  end

  def edit?
    update?
  end

  def destroy?
    false # nobody can delete right now
  end

  # Get teams where user can create projects
  # Returns Team relation
  def allowed_teams
    user.teams_for_project_creation
  end

  # Check if user can assign project to a specific team
  def can_assign_to_team?(team)
    return false unless team

    # Check if user is admin on the team
    team_role = UserPartyRole.where(user: user, party: team).first&.role
    return true if team_role == "admin"

    # Check if user is admin on the organization
    org_role = UserPartyRole.where(user: user, party: team.organization).first&.role
    return true if org_role == "admin"

    false
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
      project_ids = Project.active.where(team_id: team_ids).pluck(:id)
      project_ids |= UserPartyRole.where(user: user, party_type: "Project").pluck(:party_id)
      scope.active.where(id: project_ids)
    end

    private

    attr_reader :user, :scope
  end

  private

  def user_is_project_member?
    project_role.present?
  end

  def user_is_project_admin?
    project_role == "admin"
  end

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
