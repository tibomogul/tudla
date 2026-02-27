class AddForeignKeysForPitchAndCycleOnProjects < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :projects, :pitches, validate: false
    add_foreign_key :projects, :cycles, validate: false
  end
end
