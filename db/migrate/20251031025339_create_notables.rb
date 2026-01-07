class CreateNotables < ActiveRecord::Migration[8.1]
  def change
    create_table :notables do |t|
      t.references :notable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
