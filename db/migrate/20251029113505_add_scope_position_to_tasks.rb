class AddScopePositionToTasks < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :tasks, :scope_position, :integer
    add_index :tasks, [ :scope_id, :scope_position ], name: "index_tasks_on_scope_pos", algorithm: :concurrently
  end
end
