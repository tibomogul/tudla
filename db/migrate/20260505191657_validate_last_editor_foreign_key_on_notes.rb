class ValidateLastEditorForeignKeyOnNotes < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :notes, column: :last_editor_id
  end
end
