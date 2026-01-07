# frozen_string_literal: true

class UpdateScopeTool < ApplicationTool
  description "Update an existing scope"

  annotations(
    title: "Update Scope",
    read_only_hint: false
  )

  arguments do
    required(:scope_id).filled(:integer).description("ID of the scope to update")
    optional(:name).filled(:string).description("New name for the scope")
    optional(:description).maybe(:string).description("New description for the scope")
    optional(:nice_to_have).filled(:bool).description("Whether the scope is nice to have")
    optional(:hill_chart_progress).filled(:integer).description("Hill chart progress (0-100)")
  end

  def call(scope_id:, **params)
    scopes = Scope.where(id: scope_id)
    scopes = scope_scopes_by_user(scopes)
    scope = scopes.first

    raise "Scope not found with ID: #{scope_id}" unless scope
    
    # Authorize using Pundit - user must have update permission
    authorize(scope, :update?)

    update_params = params.slice(:name, :description, :nice_to_have, :hill_chart_progress).compact

    if scope.update(update_params)
      "Scope updated successfully!\n\n#{GetScopeTool.new.call(scope_id: scope.id)}"
    else
      raise "Failed to update scope: #{scope.errors.full_messages.join(', ')}"
    end
  end
end
