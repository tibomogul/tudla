class NotePolicy < ApplicationPolicy
  attr_reader :user, :note

  def initialize(user, note)
    @user = user
    @note = note
  end

  def create?
    can_access_notable?
  end

  def update?
    can_access_notable? && note.user == user
  end

  def destroy?
    can_access_notable? && note.user == user
  end

  def edit?
    update?
  end

  private

  def can_access_notable?
    notable_obj = note.notable
    return false unless notable_obj
    
    # For delegated types, we need to get the actual record
    # Use the polymorphic attributes directly if the delegated type accessor doesn't work
    notable_record = begin
      notable_obj.notable
    rescue
      # If delegated type fails, manually fetch the record
      notable_obj.notable_type&.constantize&.find_by(id: notable_obj.notable_id)
    end
    
    return false unless notable_record

    # Use class name comparison to avoid class reloading issues in development
    case notable_record.class.name
    when "Project"
      user_has_project_access?(notable_record)
    when "Scope"
      user_has_scope_access?(notable_record)
    when "Task"
      user_has_task_access?(notable_record)
    when "Team"
      user_has_team_access?(notable_record)
    when "Organization"
      user_has_organization_access?(notable_record)
    else
      false
    end
  end

  def user_has_project_access?(project)
    # Check direct project access first
    return true if UserPartyRole.exists?(user: user, party: project)
    
    # If project has a team, check team and org access
    if project.team
      return true if UserPartyRole.exists?(user: user, party: project.team)
      return true if UserPartyRole.exists?(user: user, party: project.team.organization)
    end
    
    false
  end

  def user_has_scope_access?(scope)
    user_has_project_access?(scope.project)
  end

  def user_has_task_access?(task)
    return true if task.responsible_user == user
    return false unless task.project

    user_has_project_access?(task.project)
  end

  def user_has_team_access?(team)
    UserPartyRole.exists?(user: user, party: team) ||
      UserPartyRole.exists?(user: user, party: team.organization)
  end

  def user_has_organization_access?(organization)
    UserPartyRole.exists?(user: user, party: organization)
  end
end
