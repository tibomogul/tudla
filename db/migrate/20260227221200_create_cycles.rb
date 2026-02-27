class CreateCycles < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :cycles do |t|
      t.string :name, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :status, default: "shaping"
      t.references :organization, null: false, foreign_key: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :cycles, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
    add_index :cycles, [ :organization_id, :start_date ], algorithm: :concurrently
    add_index :cycles, :status, algorithm: :concurrently
  end
end
