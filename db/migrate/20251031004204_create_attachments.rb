class CreateAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :attachments do |t|
      t.references :attachable, null: false, foreign_key: true
      t.text :description
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
