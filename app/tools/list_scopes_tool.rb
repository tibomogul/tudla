# frozen_string_literal: true

class ListScopesTool < ApplicationTool
  description "List scopes with optional filters"

  annotations(
    title: "List Scopes",
    read_only_hint: true
  )

  input_schema(
    properties: {
      project_id: { type: "integer", description: "Filter by project ID" },
      limit: { type: "integer", description: "Maximum number of scopes to return (default: 50)" }
    }
  )

  def execute(project_id: nil, limit: 50)
    scopes = Scope.active
    scopes = scope_scopes_by_user(scopes)
    scopes = scopes.where(project_id: project_id) if project_id

    scopes = scopes.limit(limit).order(created_at: :desc)

    format_scopes(scopes)
  end
end
