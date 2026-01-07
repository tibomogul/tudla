class AttachmentPolicy < ApplicationPolicy
  attr_reader :user, :attachment

  def initialize(user, attachment)
    @user = user
    @attachment = attachment
  end

  def create?
    can_access_attachable?
  end

  def destroy?
    can_access_attachable?
  end

  def download?
    can_access_attachable?
  end

  private

  def can_access_attachable?
    attachable_obj = attachment.attachable
    return false unless attachable_obj
    
    # For delegated types, we need to get the actual record
    # Use the polymorphic attributes directly if the delegated type accessor doesn't work
    attachable_record = begin
      attachable_obj.attachable
    rescue
      # If delegated type fails, manually fetch the record
      attachable_obj.attachable_type&.constantize&.find_by(id: attachable_obj.attachable_id)
    end
    
    return false unless attachable_record

    # Use class name comparison to avoid class reloading issues in development
    case attachable_record.class.name
    when "Project"
      user_has_project_access?(attachable_record)
    when "Scope"
      user_has_scope_access?(attachable_record)
    when "Task"
      user_has_task_access?(attachable_record)
    when "Team"
      user_has_team_access?(attachable_record)
    when "Organization"
      user_has_organization_access?(attachable_record)
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
