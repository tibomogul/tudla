class AddTodayBacklogFieldsToTasks < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :tasks, :in_today, :boolean, null: false, default: false
    add_column :tasks, :today_position, :integer
    add_column :tasks, :backlog_position, :integer
    add_column :tasks, :due_at, :datetime

    add_index :tasks, [ :responsible_user_id, :in_today, :today_position ], name: "index_tasks_on_user_today_pos", algorithm: :concurrently
    add_index :tasks, [ :responsible_user_id, :in_today, :backlog_position ], name: "index_tasks_on_user_backlog_pos", algorithm: :concurrently
    add_index :tasks, :due_at, algorithm: :concurrently
  end
end
