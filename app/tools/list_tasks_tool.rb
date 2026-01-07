# frozen_string_literal: true

class ListTasksTool < ApplicationTool
  description "List tasks with optional filters"

  annotations(
    title: "List Tasks",
    read_only_hint: true
  )

  arguments do
    optional(:project_id).filled(:integer).description("Filter by project ID")
    optional(:scope_id).filled(:integer).description("Filter by scope ID")
    optional(:responsible_user_id).filled(:integer).description("Filter by responsible user ID")
    optional(:state).filled(:string).description("Filter by state (new, in_progress, in_review, done, blocked)")
    optional(:in_today).filled(:bool).description("Filter by tasks scheduled for today")
    optional(:limit).filled(:integer).description("Maximum number of tasks to return (default: 50)")
  end

  def call(project_id: nil, scope_id: nil, responsible_user_id: nil, state: nil, in_today: nil, limit: 50)
    tasks = Task.active
    tasks = scope_tasks_by_user(tasks)
    tasks = tasks.where(project_id: project_id) if project_id
    tasks = tasks.where(scope_id: scope_id) if scope_id
    tasks = tasks.where(responsible_user_id: responsible_user_id) if responsible_user_id
    tasks = tasks.where(state: state) if state
    tasks = tasks.where(in_today: in_today) unless in_today.nil?

    tasks = tasks.limit(limit).order(created_at: :desc)

    format_tasks(tasks)
  end
end
