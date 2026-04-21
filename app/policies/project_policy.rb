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
    return false unless project.instance_of?(Project)
    return false if project.read_only?
    can_modify_project?
  end

  def edit?
    update?
  end

  def destroy?
    false # nobody can delete right now
  end

  # Gate for invoking the lifecycle transition endpoint at all.
  def transition_lifecycle?
    project.instance_of?(Project) && admin_on_project_scope?
  end

  # Per-target check that combines authz + source-state legality.
  # Allowed transitions:
  #   active   → done, archived
  #   done     → archived, active
  #   archived → active
  def can_transition_to?(to_state)
    return false unless transition_lifecycle?
    case to_state.to_sym
    when :done     then project.active?
    when :archived then project.active? || project.done?
    when :active   then !project.active?
    else false
    end
  end

  # Class-level check used by list views to decide whether to expose the
  # "Archived" filter. A user can unarchive a project only if they hold an
  # admin role on at least one project, team, or organization.
  def self.can_unarchive_any?(user)
    return false unless user
    UserPartyRole.where(user: user, role: "admin").exists?
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

  def admin_on_project_scope?
    user_is_project_admin? || user_is_team_admin? || user_is_organization_admin?
  end

  # "User may mutate this project" — used by update? and implicitly by
  # transition_lifecycle?. Delegates to the existing admin check.
  def can_modify_project?
    admin_on_project_scope?
  end
end
