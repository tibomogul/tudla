class CreateUserPartyRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :user_party_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :party, polymorphic: true, null: false
      t.string :role

      t.timestamps
    end
    add_index :user_party_roles, :role
  end
end
