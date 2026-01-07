class CreateProjectRiskTransitions < ActiveRecord::Migration[8.1]
  def change
    create_table :project_risk_transitions do |t|
      t.string :to_state, null: false
      t.jsonb :metadata, default: {}
      t.integer :sort_key, null: false
      t.references :project, null: false, foreign_key: true
      t.boolean :most_recent, null: false

      t.timestamps null: false
    end

    add_index(:project_risk_transitions,
              %i[project_id sort_key],
              unique: true,
              name: "index_project_risk_transitions_parent_sort")
    add_index(:project_risk_transitions,
              %i[project_id most_recent],
              unique: true,
              where: "most_recent",
              name: "index_project_risk_transitions_parent_most_recent")
    add_index :project_risk_transitions, :metadata, using: :gin
  end
end
