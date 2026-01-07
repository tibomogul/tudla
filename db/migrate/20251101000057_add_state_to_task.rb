class AddStateToTask < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!
  def change
    add_column :tasks, :state, :string
    add_index :tasks, :state, algorithm: :concurrently
  end
end
