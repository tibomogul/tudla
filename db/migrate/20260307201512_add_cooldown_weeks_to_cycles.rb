class AddCooldownWeeksToCycles < ActiveRecord::Migration[8.1]
  def change
    add_column :cycles, :cooldown_weeks, :integer, default: 2, null: false
  end
end
