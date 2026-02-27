class CreatePitches < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :pitches do |t|
      t.string :title, null: false
      t.text :problem
      t.integer :appetite, default: 6
      t.text :solution
      t.text :rabbit_holes
      t.text :no_gos
      t.string :status, default: "draft"
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :pitches, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
    add_index :pitches, [ :organization_id, :status ], algorithm: :concurrently
  end
end
