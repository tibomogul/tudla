# frozen_string_literal: true

class UpdateTaskTool < ApplicationTool
  description "Update an existing task"

  annotations(
    title: "Update Task",
    read_only_hint: false
  )

  arguments do
    required(:task_id).filled(:integer).description("ID of the task to update")
    optional(:name).filled(:string).description("New name for the task")
    optional(:description).maybe(:string).description("New description for the task")
    optional(:project_id).filled(:integer).description("New project ID for the task")
    optional(:scope_id).filled(:integer).description("New scope ID for the task")
    optional(:responsible_user_id).filled(:integer).description("New responsible user ID")
    optional(:due_at).filled(:string).description("New due date in ISO 8601 format")
    optional(:in_today).filled(:bool).description("Whether the task is scheduled for today")
    optional(:nice_to_have).filled(:bool).description("Whether the task is nice to have")
    optional(:unassisted_estimate).filled(:integer).description("Unassisted time estimate in hours")
    optional(:ai_assisted_estimate).filled(:integer).description("AI-assisted time estimate in hours")
    optional(:actual_manhours).filled(:integer).description("Actual time spent in hours")
  end

  def call(task_id:, **params)
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
      "Task updated successfully!\n\n#{GetTaskTool.new.call(task_id: task.id)}"
    else
      raise "Failed to update task: #{task.errors.full_messages.join(', ')}"
    end
  end
end
