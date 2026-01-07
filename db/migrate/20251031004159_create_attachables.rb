class CreateAttachables < ActiveRecord::Migration[8.1]
  def change
    create_table :attachables do |t|
      t.references :attachable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
