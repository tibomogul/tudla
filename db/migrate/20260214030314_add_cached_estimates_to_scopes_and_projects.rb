class AddCachedEstimatesToScopesAndProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :scopes, :cached_unassisted_estimate, :integer, default: 0, null: false
    add_column :scopes, :cached_ai_assisted_estimate, :integer, default: 0, null: false
    add_column :scopes, :cached_actual_manhours, :integer, default: 0, null: false

    add_column :projects, :cached_unassisted_estimate, :integer, default: 0, null: false
    add_column :projects, :cached_ai_assisted_estimate, :integer, default: 0, null: false
    add_column :projects, :cached_actual_manhours, :integer, default: 0, null: false
  end
end
