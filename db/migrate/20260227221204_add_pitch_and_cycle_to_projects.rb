class AddPitchAndCycleToProjects < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :projects, :pitch, null: true, index: { algorithm: :concurrently }
    add_reference :projects, :cycle, null: true, index: { algorithm: :concurrently }
  end
end
