class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :links do |t|
      t.references :linkable, null: false, foreign_key: true
      t.string :url
      t.text :description
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
