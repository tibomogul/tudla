class AddScopeIdToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :scope_id, :integer, null: true
    add_index :tasks, :scope_id
  end
end
