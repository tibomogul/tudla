class ReportPolicy < ApplicationPolicy
  attr_reader :user, :report

  def initialize(user, report)
    @user = user
    @report = report
  end

  def index?
    true # anybody can go to the index, but the list is scoped
  end

  def show?
    is_owner? || can_view_reportable?
  end

  def create?
    true # any logged-in user can create a report
  end

  def new?
    create?
  end

  def update?
    is_owner? && !report.submitted?
  end

  def edit?
    update?
  end

  def destroy?
    is_owner? && !report.submitted?
  end

  def submit?
    is_owner? && !report.submitted?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      # Get all reportables the user has access to
      org_ids = UserPartyRole
        .where(user: user, party_type: "Organization")
        .pluck(:party_id)
      
      team_ids = Team.active.where(organization_id: org_ids).pluck(:id)
      team_ids |= UserPartyRole
        .where(user: user, party_type: "Team")
        .pluck(:party_id)
      
      project_ids = Project.active.where(team_id: team_ids).pluck(:id)
      project_ids |= UserPartyRole
        .where(user: user, party_type: "Project")
        .pluck(:party_id)

      # Get reportable IDs for teams and projects
      team_reportable_ids = Reportable.where(reportable_type: "Team", reportable_id: team_ids).pluck(:id)
      project_reportable_ids = Reportable.where(reportable_type: "Project", reportable_id: project_ids).pluck(:id)
      
      # Return reports the user owns or reports for accessible reportables
      # Only show submitted reports OR drafts owned by current user
      scope
        .active
        .where("reports.user_id = ? OR reports.reportable_id IN (?)", user.id, team_reportable_ids + project_reportable_ids)
        .where("reports.submitted_at IS NOT NULL OR reports.user_id = ?", user.id)
    end

    private

    attr_reader :user, :scope
  end

  private

  def is_owner?
    report.user == user
  end

  def can_view_reportable?
    return false unless report.reportable&.reportable

    reportable = report.reportable.reportable

    case reportable
    when Team
      user_has_team_access?(reportable)
    when Project
      user_has_project_access?(reportable)
    else
      false
    end
  end

  def user_has_team_access?(team)
    # Check if user is team member or organization member
    UserPartyRole.exists?(user: user, party: team) ||
      UserPartyRole.exists?(user: user, party: team.organization)
  end

  def user_has_project_access?(project)
    # Check if user is project member, team member, or organization member
    return false unless project.team

    UserPartyRole.exists?(user: user, party: project) ||
      UserPartyRole.exists?(user: user, party: project.team) ||
      UserPartyRole.exists?(user: user, party: project.team.organization)
  end
end
