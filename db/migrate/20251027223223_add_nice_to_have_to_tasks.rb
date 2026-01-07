class AddNiceToHaveToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :nice_to_have, :boolean, default: false, null: false
  end
end
