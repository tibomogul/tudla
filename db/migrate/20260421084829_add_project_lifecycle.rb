class AddProjectLifecycle < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :projects, :lifecycle_state, :string, null: false, default: "active"
    add_column :projects, :done_at, :datetime
    add_column :projects, :archived_at, :datetime
    add_index  :projects, :lifecycle_state, algorithm: :concurrently

    add_column :scopes, :project_lifecycle_state, :string, null: false, default: "active"
    add_column :tasks,  :project_lifecycle_state, :string, null: false, default: "active"
    add_index  :scopes, :project_lifecycle_state, algorithm: :concurrently
    add_index  :tasks,  :project_lifecycle_state, algorithm: :concurrently

    create_table :project_lifecycle_transitions do |t|
      t.string  :to_state, null: false
      t.jsonb   :metadata, default: {}
      t.integer :sort_key, null: false
      t.references :project, null: false, foreign_key: true
      t.boolean :most_recent, null: false

      t.timestamps null: false
    end

    add_index(:project_lifecycle_transitions,
              %i[project_id sort_key],
              unique: true,
              name: "index_project_lifecycle_transitions_parent_sort")
    add_index(:project_lifecycle_transitions,
              %i[project_id most_recent],
              unique: true,
              where: "most_recent",
              name: "index_project_lifecycle_transitions_parent_most_recent")
    add_index :project_lifecycle_transitions, :metadata, using: :gin
  end
end
