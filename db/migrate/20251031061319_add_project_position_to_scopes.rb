class AddProjectPositionToScopes < ActiveRecord::Migration[8.1]
  def change
    add_column :scopes, :project_position, :integer
  end
end
