class AddPreferredNameToUser < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :preferred_name, :string
    add_index :users, :preferred_name
  end
end
