# frozen_string_literal: true

class GetTaskTool < ApplicationTool
  description "Get detailed information about a specific task"

  annotations(
    title: "Get Task Details",
    read_only_hint: true
  )

  input_schema(
    properties: {
      task_id: { type: "integer", description: "ID of the task to retrieve" }
    },
    required: [ "task_id" ]
  )

  def execute(task_id:)
    tasks = Task.where(id: task_id)
    tasks = scope_tasks_by_user(tasks)
    task = tasks.first

    raise "Task not found with ID: #{task_id}" unless task

    format_task_details(task)
  end
end
