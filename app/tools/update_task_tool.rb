# frozen_string_literal: true

class UpdateTaskTool < ApplicationTool
  description "Update an existing task"

  annotations(
    title: "Update Task",
    read_only_hint: false
  )

  input_schema(
    properties: {
      task_id: { type: "integer", description: "ID of the task to update" },
      name: { type: "string", description: "New name for the task" },
      description: { type: "string", description: "New description for the task" },
      project_id: { type: "integer", description: "New project ID for the task" },
      scope_id: { type: "integer", description: "New scope ID for the task" },
      responsible_user_id: { type: "integer", description: "New responsible user ID" },
      due_at: { type: "string", description: "New due date in ISO 8601 format" },
      in_today: { type: "boolean", description: "Whether the task is scheduled for today" },
      nice_to_have: { type: "boolean", description: "Whether the task is nice to have" },
      unassisted_estimate: { type: "integer", description: "Unassisted time estimate in hours" },
      ai_assisted_estimate: { type: "integer", description: "AI-assisted time estimate in hours" },
      actual_manhours: { type: "integer", description: "Actual time spent in hours" }
    },
    required: [ "task_id" ]
  )

  def execute(task_id:, **params)
    tasks = Task.where(id: task_id)
    tasks = scope_tasks_by_user(tasks)
    task = tasks.first

    raise "Task not found with ID: #{task_id}" unless task

    # Authorize using Pundit - user must have update permission
    authorize(task, :update?)

    update_params = params.slice(:name, :description, :project_id, :scope_id,
                                  :responsible_user_id, :in_today, :nice_to_have,
                                  :unassisted_estimate, :ai_assisted_estimate, :actual_manhours).compact

    if params[:due_at]
      update_params[:due_at] = Time.zone.parse(params[:due_at])
    end

    if task.update(update_params)
      "Task updated successfully!\n\n#{call_tool(GetTaskTool, task_id: task.id)}"
    else
      raise "Failed to update task: #{task.errors.full_messages.join(', ')}"
    end
  end
end
