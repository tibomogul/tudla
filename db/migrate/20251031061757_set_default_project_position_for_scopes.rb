class SetDefaultProjectPositionForScopes < ActiveRecord::Migration[8.1]
  def up
    # Set project_position for existing scopes based on their ID order
    # Group by project_id and assign positions
    safety_assured do
      execute <<-SQL
        WITH numbered_scopes AS (
          SELECT id, ROW_NUMBER() OVER (PARTITION BY project_id ORDER BY id) - 1 AS position
          FROM scopes
          WHERE project_position IS NULL
        )
        UPDATE scopes
        SET project_position = numbered_scopes.position
        FROM numbered_scopes
        WHERE scopes.id = numbered_scopes.id
      SQL
    end
  end

  def down
    # Optional: reset positions to NULL if rolling back
    execute "UPDATE scopes SET project_position = NULL"
  end
end
