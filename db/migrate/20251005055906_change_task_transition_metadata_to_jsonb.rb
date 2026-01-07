class ChangeTaskTransitionMetadataToJsonb < ActiveRecord::Migration[8.0]
  def change
    change_column_default :task_transitions, :metadata, nil
    change_column :task_transitions, :metadata, :jsonb, using: 'metadata::jsonb'
    change_column_default :task_transitions, :metadata, {}
    add_index :task_transitions, :metadata, using: :gin
  end
end
