# frozen_string_literal: true

class ApplicationTool < MCP::Tool
  include McpFormatters

  # Shared logic for all tools
  #
  # Pattern: self.call (required by MCP::Tool) delegates to #execute on an instance.
  # Subclasses define `def execute(...)` instead of overriding self.call.
  # This lets tools use instance methods (formatters, auth helpers) naturally.

  attr_reader :server_context

  def self.call(server_context:, **args)
    instance = new(server_context)
    text = instance.execute(**args)
    MCP::Tool::Response.new([ { type: "text", text: text } ])
  rescue Pundit::NotAuthorizedError => e
    MCP::Tool::Response.new([ { type: "text", text: "Authorization error: #{e.message}" } ], error: true)
  rescue StandardError => e
    Rails.logger.error "MCP Tool Error (#{name}): #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}"
    MCP::Tool::Response.new([ { type: "text", text: "Error: #{e.message}" } ], error: true)
  end

  def initialize(server_context)
    @server_context = server_context
  end

  # Get the current user from the MCP authentication context
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = server_context[:user]
    Rails.logger.info "MCP Tool: current_user = #{@current_user&.id || 'nil'}"
    raise "Authentication required. Please provide a valid Bearer token." unless @current_user
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

  # Call another tool's execute method with the same server_context
  def call_tool(tool_class, **args)
    tool_class.new(server_context).execute(**args)
  end
end
