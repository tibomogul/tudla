# frozen_string_literal: true

class TransitionTaskStateTool < ApplicationTool
  description "Transition a task to a new state using the state machine"

  annotations(
    title: "Transition Task State",
    read_only_hint: false
  )

  input_schema(
    properties: {
      task_id: { type: "integer", description: "ID of the task to transition" },
      state: { type: "string", description: "Target state (new, in_progress, in_review, done, blocked)" },
      user_id: { type: "integer", description: "ID of the user performing the transition (optional)" }
    },
    required: %w[task_id state]
  )

  def execute(task_id:, state:, user_id: nil)
    tasks = Task.where(id: task_id)
    tasks = scope_tasks_by_user(tasks)
    task = tasks.first

    raise "Task not found with ID: #{task_id}" unless task

    # Authorize using Pundit - user must have update permission
    authorize(task, :update?)

    new_state = state.to_sym
    metadata = {}
    metadata[:user_id] = user_id || current_user&.id
    metadata[:user_id] = metadata[:user_id].to_i if metadata[:user_id]

    if task.state_machine.can_transition_to?(new_state)
      task.state_machine.transition_to!(new_state, metadata)
      task.reload

      "Task state transitioned successfully to #{new_state}!\n\n#{call_tool(GetTaskTool, task_id: task.id)}"
    else
      allowed = task.state_machine.allowed_transitions.join(", ")
      raise "Cannot transition from #{task.current_state} to #{new_state}. Allowed transitions: #{allowed}"
    end
  end
end
