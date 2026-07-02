class AddUniqueIndexToSubscriptions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Remove duplicate subscriptions (keep the earliest) before enforcing uniqueness.
    safety_assured do
      execute <<~SQL
        DELETE FROM subscriptions a
        USING subscriptions b
        WHERE a.user_id = b.user_id
          AND a.subscribable_id = b.subscribable_id
          AND a.id > b.id
      SQL
    end

    remove_index :subscriptions, [ :user_id, :subscribable_id ], algorithm: :concurrently, if_exists: true
    add_index :subscriptions, [ :user_id, :subscribable_id ], unique: true, algorithm: :concurrently
  end

  def down
    remove_index :subscriptions, [ :user_id, :subscribable_id ], algorithm: :concurrently, if_exists: true
    add_index :subscriptions, [ :user_id, :subscribable_id ], algorithm: :concurrently
  end
end
