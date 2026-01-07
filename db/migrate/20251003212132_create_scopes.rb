class CreateScopes < ActiveRecord::Migration[8.0]
  def change
    create_table :scopes do |t|
      t.string :name
      t.text :description
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
    add_index :scopes, :name
  end
end
