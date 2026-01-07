# frozen_string_literal: true

class AssignTaskTool < ApplicationTool
  description "Assign a task to a user"

  annotations(
    title: "Assign Task",
    read_only_hint: false
  )

  arguments do
    required(:task_id).filled(:integer).description("ID of the task to assign")
    required(:user_id).filled(:integer).description("ID of the user to assign the task to")
  end

  def call(task_id:, user_id:)
    tasks = Task.where(id: task_id)
    tasks = scope_tasks_by_user(tasks)
    task = tasks.first
    user = User.find_by(id: user_id)

    raise "Task not found with ID: #{task_id}" unless task
    raise "User not found with ID: #{user_id}" unless user
    
    # Authorize using Pundit - user must have update permission
    authorize(task, :update?)

    if task.update(responsible_user_id: user.id)
      user_name = user.username || user.preferred_name || user.email
      "Task assigned successfully to #{user_name}!\n\n#{GetTaskTool.new.call(task_id: task.id)}"
    else
      raise "Failed to assign task: #{task.errors.full_messages.join(', ')}"
    end
  end
end
