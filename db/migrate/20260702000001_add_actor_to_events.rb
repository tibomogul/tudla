class AddActorToEvents < ActiveRecord::Migration[8.0]
  def change
    # Events table is empty (pipeline was never wired), so these are safe.
    safety_assured do
      change_column_null :events, :user_id, true
      add_column :events, :actor_type, :string, null: false, default: "user"
      add_column :events, :actor_label, :string
    end
  end
end
