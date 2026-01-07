class AddResponsibleUserToTask < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :responsible_user_id, :bigint
  end
end
