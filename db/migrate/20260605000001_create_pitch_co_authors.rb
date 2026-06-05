class CreatePitchCoAuthors < ActiveRecord::Migration[8.1]
  def change
    create_table :pitch_co_authors do |t|
      # No standalone pitch_id index: the composite unique index below covers
      # pitch_id as its leftmost prefix.
      t.references :pitch, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :pitch_co_authors, %i[pitch_id user_id], unique: true
  end
end
