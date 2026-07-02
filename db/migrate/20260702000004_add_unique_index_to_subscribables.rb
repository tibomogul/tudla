class AddUniqueIndexToSubscribables < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Duplicate containers can exist because callers used non-atomic
    # find_or_create_by!. Keep the earliest container per subject and fold the
    # duplicates' children into it before enforcing uniqueness.
    safety_assured do
      # Drop subscriptions that would collide with one already on (or moving to)
      # the keeper: keep the earliest subscription per user + subject group.
      execute <<~SQL
        DELETE FROM subscriptions a
        USING subscriptions b, subscribables sa, subscribables sb
        WHERE sa.id = a.subscribable_id
          AND sb.id = b.subscribable_id
          AND sa.subscribable_type = sb.subscribable_type
          AND sa.subscribable_id = sb.subscribable_id
          AND a.user_id = b.user_id
          AND a.id > b.id
      SQL

      # Repoint surviving subscriptions and events to the keeper container.
      %w[subscriptions events].each do |table|
        execute <<~SQL
          UPDATE #{table} c
          SET subscribable_id = k.keep_id
          FROM subscribables dup,
               LATERAL (
                 SELECT MIN(id) AS keep_id FROM subscribables s
                 WHERE s.subscribable_type = dup.subscribable_type
                   AND s.subscribable_id = dup.subscribable_id
               ) k
          WHERE c.subscribable_id = dup.id
            AND dup.id <> k.keep_id
        SQL
      end

      execute <<~SQL
        DELETE FROM subscribables a
        USING subscribables b
        WHERE a.subscribable_type = b.subscribable_type
          AND a.subscribable_id = b.subscribable_id
          AND a.id > b.id
      SQL
    end

    remove_index :subscribables, name: "index_subscribables_on_subscribable", algorithm: :concurrently, if_exists: true
    add_index :subscribables, [ :subscribable_type, :subscribable_id ],
      unique: true, name: "index_subscribables_on_subscribable", algorithm: :concurrently
  end

  def down
    remove_index :subscribables, name: "index_subscribables_on_subscribable", algorithm: :concurrently, if_exists: true
    add_index :subscribables, [ :subscribable_type, :subscribable_id ],
      name: "index_subscribables_on_subscribable", algorithm: :concurrently
  end
end
