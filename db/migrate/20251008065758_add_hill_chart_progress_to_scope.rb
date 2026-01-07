class AddHillChartProgressToScope < ActiveRecord::Migration[8.0]
  def change
    add_column :scopes, :hill_chart_progress, :integer,
      limit: 1, null: false, default: 0 # values 0-100
  end
end
