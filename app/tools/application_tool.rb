# frozen_string_literal: true

class ApplicationTool < ActionTool::Base
  include McpFormatters
  
  # Shared logic for all tools
  
  # Get the current user from the MCP authentication context
  def current_user
    return @current_user if defined?(@current_user)
    
    # Fast-mcp stores the authenticated user in Thread.current during request processing
    @current_user = Thread.current[:mcp_current_user]
    
    Rails.logger.info "MCP Tool: current_user = #{@current_user&.id || 'nil'}"
    @current_user
  end
  
  # Authorize an action using Pundit (single source of truth for permissions)
  # Raises Pundit::NotAuthorizedError if user is not authorized
  def authorize(record, query)
    policy = Pundit.policy!(current_user, record)
    
    unless policy.public_send(query)
      raise Pundit::NotAuthorizedError, "Not authorized to #{query.to_s.delete_suffix('?')} this #{record.class.name}"
    end
    
    true
  end
  
  # Scope tasks by current user's permissions using Pundit
  # Delegates to TaskPolicy::Scope for single source of truth
  def scope_tasks_by_user(tasks)
    return tasks unless current_user
    
    TaskPolicy::Scope.new(current_user, tasks).resolve
  end

  # Scope scopes by current user's permissions using Pundit
  # Delegates to ScopePolicy::Scope for single source of truth
  def scope_scopes_by_user(scopes)
    return scopes unless current_user
    
    ScopePolicy::Scope.new(current_user, scopes).resolve
  end

  # Scope projects by current user's permissions using Pundit
  # Delegates to ProjectPolicy::Scope for single source of truth
  def scope_projects_by_user(projects)
    return projects unless current_user
    
    ProjectPolicy::Scope.new(current_user, projects).resolve
  end
end
