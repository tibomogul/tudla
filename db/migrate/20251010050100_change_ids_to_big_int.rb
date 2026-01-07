class ChangeIdsToBigInt < ActiveRecord::Migration[8.0]
  def change
    change_column :task_transitions, :task_id, :bigint
    change_column :tasks, :scope_id, :bigint
  end
end
