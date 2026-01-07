class CreateTaskTransitions < ActiveRecord::Migration[8.0]
  def change
    create_table :task_transitions do |t|
      t.string :to_state, null: false
      t.text :metadata, default: "{}"
      t.integer :sort_key, null: false
      t.integer :task_id, null: false
      t.boolean :most_recent, null: false

      # If you decide not to include an updated timestamp column in your transition
      # table, you'll need to configure the `updated_timestamp_column` setting in your
      # migration class.
      t.timestamps null: false
    end

    # Foreign keys are optional, but highly recommended
    add_foreign_key :task_transitions, :tasks

    add_index(:task_transitions,
              %i[task_id sort_key],
              unique: true,
              name: "index_task_transitions_parent_sort")
    add_index(:task_transitions,
              %i[task_id most_recent],
              unique: true,
              where: "most_recent",
              name: "index_task_transitions_parent_most_recent")
  end
end
