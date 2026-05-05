class AddLastEditorForeignKeyToNotes < ActiveRecord::Migration[8.1]
  def change
    unless foreign_key_exists?(:notes, :users, column: :last_editor_id)
      add_foreign_key :notes, :users, column: :last_editor_id, validate: false
    end
  end
end
