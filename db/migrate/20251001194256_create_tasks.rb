class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.string :name
      t.text :description
      t.references :project, null: true, foreign_key: true

      t.timestamps
    end
    add_index :tasks, :name
  end
end
