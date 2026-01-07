# frozen_string_literal: true

module McpFormatters
  # Task Formatters
  
  def format_tasks(tasks)
    return "No tasks found." if tasks.empty?

    output = "Found #{tasks.count} task(s):\n\n"
    tasks.each do |task|
      output += format_task_summary(task)
      output += "\n---\n\n"
    end
    output
  end

  def format_task_summary(task)
    <<~TEXT
      ID: #{task.id}
      Name: #{task.name}
      State: #{task.current_state}
      Project: #{task.project&.name || 'None'}
      Scope: #{task.scope&.name || 'None'}
      Assigned to: #{format_user(task.responsible_user)}
      Due: #{format_datetime(task.due_at)}
      In Today: #{task.in_today}
      Nice to Have: #{task.nice_to_have}
      Unassisted Estimate: #{task.unassisted_estimate || 'Not provided'} hours
      AI Assisted Estimate: #{task.ai_assisted_estimate || 'Not provided'} hours
      Actual: #{task.actual_manhours || 'Not provided'} hours
    TEXT
  end

  def format_task_details(task)
    output = format_task_summary(task)
    output += "\nDescription:\n#{task.description || 'No description'}\n"

    if task.task_transitions.any?
      output += "\nState History:\n"
      task.task_transitions.order(:sort_key).each do |transition|
        user_info = transition.metadata["user_id"] ? " (User ID: #{transition.metadata['user_id']})" : ""
        output += "  - #{transition.to_state} at #{format_datetime(transition.created_at)}#{user_info}\n"
      end
    end

    allowed_transitions = task.state_machine.allowed_transitions
    if allowed_transitions.any?
      output += "\nAllowed Transitions: #{allowed_transitions.join(', ')}\n"
    end

    output
  end

  # Scope Formatters

  def format_scopes(scopes)
    return "No scopes found." if scopes.empty?

    output = "Found #{scopes.count} scope(s):\n\n"
    scopes.each do |scope|
      output += format_scope_summary(scope)
      output += "\n---\n\n"
    end
    output
  end

  def format_scope_summary(scope)
    <<~TEXT
      ID: #{scope.id}
      Name: #{scope.name}
      Project: #{scope.project.name}
      Progress: #{scope.percent_done}% complete
      Hill Chart Progress: #{scope.hill_chart_progress}
      Nice to Have: #{scope.nice_to_have}
      Tasks: #{scope.tasks.count}
    TEXT
  end

  def format_scope_details(scope)
    output = format_scope_summary(scope)
    output += "\nDescription:\n#{scope.description || 'No description'}\n"

    if scope.tasks.any?
      output += "\nTasks (#{scope.tasks.count}):\n"
      scope.tasks.order(:scope_position).each do |task|
        output += "  - [#{task.current_state}] #{task.name} (ID: #{task.id})\n"
      end
    end

    output
  end

  # Project Formatters

  def format_projects(projects)
    return "No projects found." if projects.empty?

    output = "Found #{projects.count} project(s):\n\n"
    projects.each do |project|
      output += format_project_summary(project)
      output += "\n---\n\n"
    end
    output
  end

  def format_project_summary(project)
    <<~TEXT
      ID: #{project.id}
      Name: #{project.name}
      Team: #{project.team&.name || 'No team'}
      Risk State: #{project.risk_state || 'Not set'}
      Scopes: #{project.scopes.count}
      Tasks: #{project.tasks.count}
    TEXT
  end

  def format_project_details(project)
    output = format_project_summary(project)
    output += "\nDescription:\n#{project.description || 'No description'}\n"

    if project.scopes.any?
      output += "\nScopes (#{project.scopes.count}):\n"
      project.scopes.order(:project_position).each do |scope|
        output += "  - #{scope.name} (ID: #{scope.id}) - #{scope.percent_done}% complete\n"
      end
    end

    output
  end

  # Helper Formatters

  def format_user(user)
    return 'Unassigned' unless user
    
    user.username || user.preferred_name || user.email
  end

  def format_datetime(datetime)
    return 'No due date' unless datetime
    
    datetime.strftime('%Y-%m-%d %H:%M')
  end
end
