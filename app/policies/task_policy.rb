class TaskPolicy < ApplicationPolicy
  attr_reader :user, :task, :owner, :project_role, :team_role, :organization_role

  def initialize(user, task)
    @user = user
    @task = task
    if task.instance_of? Task
      if task.project.present?
        @project_role = UserPartyRole.where(user: user, party: task.project).first&.role
        @team_role = UserPartyRole.where(user: user, party: task.project.team).first&.role
        @organization_role = UserPartyRole.where(user: user, party: task.project.team.organization).first&.role
      end
    end
  end

  def index?
    true # anybody can go to the index, but the list is scoped
  end

  def show?
    is_owner? || user_is_project_member? || user_is_team_member? || user_is_organization_member?
  end

  def create?
    is_owner? || user_is_project_member? || user_is_team_member?|| user_is_organization_admin?
  end

  def new?
    create?
  end

  def update?
    is_owner? || user_is_project_member? || user_is_team_member?|| user_is_organization_admin?
  end

  def edit?
    update?
  end

  def destroy?
    is_owner? # can delete personal tasks
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      # Include tasks user owns OR tasks in user's accessible projects
      org_ids = UserPartyRole
        .where(user: user, party_type: "Organization")
        .pluck(:party_id)
      team_ids = Team.active.where(organization_id: org_ids).pluck(:id)
      team_ids |= UserPartyRole
        .where(user: user, party_type: "Team")
        .pluck(:party_id)
      project_ids = Project.active.where(team_id: team_ids).pluck(:id)
      project_ids |= UserPartyRole.where(user: user, party_type: "Project").pluck(:party_id)
      
      # Return tasks the user owns OR tasks in their accessible projects
      scope.active.where("responsible_user_id = ? OR project_id IN (?)", user.id, project_ids)
    end

    private

    attr_reader :user, :scope
  end

  private

  def is_owner?
    task.responsible_user.presence == user
  end

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
