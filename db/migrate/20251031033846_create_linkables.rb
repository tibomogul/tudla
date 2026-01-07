class CreateLinkables < ActiveRecord::Migration[8.1]
  def change
    create_table :linkables do |t|
      t.references :linkable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
