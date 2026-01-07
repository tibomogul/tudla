class AddEstimatesToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :unassisted_estimate, :integer
    add_column :tasks, :ai_assisted_estimate, :integer
    add_column :tasks, :actual_manhours, :integer
  end
end
