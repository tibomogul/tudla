class AddSoftDeleteToModels < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Add deleted_at column to each soft-deletable model
    add_column :projects, :deleted_at, :datetime
    add_column :scopes, :deleted_at, :datetime
    add_column :tasks, :deleted_at, :datetime
    add_column :notes, :deleted_at, :datetime
    add_column :links, :deleted_at, :datetime
    add_column :attachments, :deleted_at, :datetime
    add_column :organizations, :deleted_at, :datetime
    add_column :teams, :deleted_at, :datetime
    add_column :reports, :deleted_at, :datetime
    add_column :api_tokens, :deleted_at, :datetime

    # Add indexes concurrently for production safety (partial indexes for NULL values)
    add_index :projects, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
    add_index :scopes, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
    add_index :tasks, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
    add_index :notes, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
    add_index :links, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
    add_index :attachments, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
    add_index :organizations, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
    add_index :teams, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
    add_index :reports, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
    add_index :api_tokens, :deleted_at, where: "deleted_at IS NULL", algorithm: :concurrently
  end
end
