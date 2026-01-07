class CreateReportables < ActiveRecord::Migration[8.1]
  def change
    create_table :reportables do |t|
      t.references :reportable, polymorphic: true, null: false
      t.timestamps
    end
    create_table :report_requirements do |t|
      t.references :reportable, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.jsonb :schedule, null: false, default: {}
      t.integer :reminder
      t.jsonb :delivery, null: false, default: {}
      t.text :template
      t.timestamps
    end
    create_table :reports do |t|
      t.references :reportable, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.text :content, null: false
      t.datetime :submitted_at
      t.datetime :as_of_at
      t.timestamps
    end
  end
end
