class AddRiskStateToProject < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!
  def change
    add_column :projects, :risk_state, :string
    add_index :projects, :risk_state, algorithm: :concurrently
  end
end
