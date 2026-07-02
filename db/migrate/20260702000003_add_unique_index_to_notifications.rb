class AddUniqueIndexToNotifications < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :notifications, [ :event_id, :user_id ], unique: true, algorithm: :concurrently
  end
end
