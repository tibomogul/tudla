class CreateSubscribableNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :subscribables do |t|
      t.references :subscribable, polymorphic: true, null: false
      t.timestamps
    end

    # add_index :subscribables, [ :subscribable_type, :subscribable_id ]

    create_table :subscriptions do |t|
      t.references :subscribable, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.timestamps
    end

    add_index :subscriptions, [ :user_id, :subscribable_id ]

    create_table :events do |t|
      t.references :subscribable, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    create_table :notifications do |t|
      t.references :event, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.datetime :read_at
      t.timestamps
    end

    add_index :notifications, [ :user_id, :created_at ], order: { created_at: :desc }
    add_index :notifications, :read_at, where: "read_at IS NULL"
  end
end
