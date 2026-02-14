# frozen_string_literal: true

class CreateTaskTool < ApplicationTool
  description "Create a new task"

  annotations(
    title: "Create Task",
    read_only_hint: false
  )

  input_schema(
    properties: {
      name: { type: "string", description: "Name of the task" },
      description: { type: "string", description: "Description of the task" },
      project_id: { type: "integer", description: "Project ID for the task" },
      scope_id: { type: "integer", description: "Scope ID for the task" },
      responsible_user_id: { type: "integer", description: "ID of the user responsible for the task" },
      due_at: { type: "string", description: "Due date in ISO 8601 format (e.g., '2024-12-31T23:59:59Z')" },
      in_today: { type: "boolean", description: "Whether the task is scheduled for today" },
      nice_to_have: { type: "boolean", description: "Whether the task is nice to have (not required)" },
      unassisted_estimate: { type: "integer", description: "Unassisted time estimate in hours" },
      ai_assisted_estimate: { type: "integer", description: "AI-assisted time estimate in hours" },
      actual_manhours: { type: "integer", description: "Actual time spent in hours" }
    },
    required: [ "name" ]
  )

  def execute(name:, description: nil, project_id: nil, scope_id: nil, responsible_user_id: nil,
              due_at: nil, in_today: false, nice_to_have: false, unassisted_estimate: nil,
              ai_assisted_estimate: nil, actual_manhours: nil)
    task = Task.new(
      name: name,
      description: description,
      project_id: project_id,
      scope_id: scope_id,
      responsible_user_id: responsible_user_id,
      in_today: in_today,
      nice_to_have: nice_to_have,
      unassisted_estimate: unassisted_estimate,
      ai_assisted_estimate: ai_assisted_estimate,
      actual_manhours: actual_manhours
    )

    task.due_at = Time.zone.parse(due_at) if due_at

    # Authorize using Pundit - user must have create permission
    authorize(task, :create?)

    if task.save
      "Task created successfully!\n\n#{call_tool(GetTaskTool, task_id: task.id)}"
    else
      raise "Failed to create task: #{task.errors.full_messages.join(', ')}"
    end
  end
end
