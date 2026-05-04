class AddLastEditorIdToNotes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    unless column_exists?(:notes, :last_editor_id)
      add_reference :notes, :last_editor, null: true, index: { algorithm: :concurrently }
    end

    reversible do |dir|
      dir.up do
        safety_assured do
          execute <<~SQL.squish
            UPDATE notes SET last_editor_id = user_id WHERE last_editor_id IS NULL
          SQL
        end
      end
    end
  end
end
