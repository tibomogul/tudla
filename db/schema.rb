# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_14_030314) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "name"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["deleted_at"], name: "index_api_tokens_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
    t.index ["user_id", "active"], name: "index_api_tokens_on_user_id_and_active"
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "attachables", force: :cascade do |t|
    t.bigint "attachable_id", null: false
    t.string "attachable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["attachable_type", "attachable_id"], name: "index_attachables_on_attachable"
  end

  create_table "attachments", force: :cascade do |t|
    t.bigint "attachable_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["attachable_id"], name: "index_attachments_on_attachable_id"
    t.index ["deleted_at"], name: "index_attachments_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["user_id"], name: "index_attachments_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "subscribable_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["subscribable_id"], name: "index_events_on_subscribable_id"
    t.index ["user_id"], name: "index_events_on_user_id"
  end

  create_table "linkables", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "linkable_id", null: false
    t.string "linkable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["linkable_type", "linkable_id"], name: "index_linkables_on_linkable"
  end

  create_table "links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.bigint "linkable_id", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "user_id", null: false
    t.index ["deleted_at"], name: "index_links_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["linkable_id"], name: "index_links_on_linkable_id"
    t.index ["user_id"], name: "index_links_on_user_id"
  end

  create_table "notables", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "notable_id", null: false
    t.string "notable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["notable_type", "notable_id"], name: "index_notables_on_notable"
  end

  create_table "notes", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "notable_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["deleted_at"], name: "index_notes_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["notable_id"], name: "index_notes_on_notable_id"
    t.index ["user_id"], name: "index_notes_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_id"], name: "index_notifications_on_event_id"
    t.index ["read_at"], name: "index_notifications_on_read_at", where: "(read_at IS NULL)"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at", order: { created_at: :desc }
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "name"
    t.string "timezone", default: "Australia/Brisbane", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_organizations_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["name"], name: "index_organizations_on_name"
  end

  create_table "project_risk_transitions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.boolean "most_recent", null: false
    t.bigint "project_id", null: false
    t.integer "sort_key", null: false
    t.string "to_state", null: false
    t.datetime "updated_at", null: false
    t.index ["metadata"], name: "index_project_risk_transitions_on_metadata", using: :gin
    t.index ["project_id", "most_recent"], name: "index_project_risk_transitions_parent_most_recent", unique: true, where: "most_recent"
    t.index ["project_id", "sort_key"], name: "index_project_risk_transitions_parent_sort", unique: true
    t.index ["project_id"], name: "index_project_risk_transitions_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.integer "cached_actual_manhours", default: 0, null: false
    t.integer "cached_ai_assisted_estimate", default: 0, null: false
    t.integer "cached_unassisted_estimate", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name"
    t.string "risk_state"
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_projects_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["name"], name: "index_projects_on_name"
    t.index ["risk_state"], name: "index_projects_on_risk_state"
    t.index ["team_id"], name: "index_projects_on_team_id"
  end

  create_table "report_requirements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "delivery", default: {}, null: false
    t.integer "reminder"
    t.bigint "reportable_id", null: false
    t.jsonb "schedule", default: {}, null: false
    t.text "template"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["reportable_id"], name: "index_report_requirements_on_reportable_id"
    t.index ["user_id"], name: "index_report_requirements_on_user_id"
  end

  create_table "reportables", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "reportable_id", null: false
    t.string "reportable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["reportable_type", "reportable_id"], name: "index_reportables_on_reportable"
  end

  create_table "reports", force: :cascade do |t|
    t.datetime "as_of_at"
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "reportable_id", null: false
    t.datetime "submitted_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["deleted_at"], name: "index_reports_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["reportable_id"], name: "index_reports_on_reportable_id"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "scopes", force: :cascade do |t|
    t.integer "cached_actual_manhours", default: 0, null: false
    t.integer "cached_ai_assisted_estimate", default: 0, null: false
    t.integer "cached_unassisted_estimate", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.integer "hill_chart_progress", limit: 2, default: 0, null: false
    t.string "name"
    t.boolean "nice_to_have", default: false, null: false
    t.bigint "project_id", null: false
    t.integer "project_position"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_scopes_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["name"], name: "index_scopes_on_name"
    t.index ["project_id"], name: "index_scopes_on_project_id"
  end

  create_table "subscribables", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "subscribable_id", null: false
    t.string "subscribable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["subscribable_type", "subscribable_id"], name: "index_subscribables_on_subscribable"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "subscribable_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["subscribable_id"], name: "index_subscriptions_on_subscribable_id"
    t.index ["user_id", "subscribable_id"], name: "index_subscriptions_on_user_id_and_subscribable_id"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "task_transitions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.boolean "most_recent", null: false
    t.integer "sort_key", null: false
    t.bigint "task_id", null: false
    t.string "to_state", null: false
    t.datetime "updated_at", null: false
    t.index ["metadata"], name: "index_task_transitions_on_metadata", using: :gin
    t.index ["task_id", "most_recent"], name: "index_task_transitions_parent_most_recent", unique: true, where: "most_recent"
    t.index ["task_id", "sort_key"], name: "index_task_transitions_parent_sort", unique: true
  end

  create_table "tasks", force: :cascade do |t|
    t.integer "actual_manhours"
    t.integer "ai_assisted_estimate"
    t.integer "backlog_position"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.datetime "due_at"
    t.boolean "in_today", default: false, null: false
    t.string "name"
    t.boolean "nice_to_have", default: false, null: false
    t.bigint "project_id"
    t.bigint "responsible_user_id"
    t.bigint "scope_id"
    t.integer "scope_position"
    t.string "state"
    t.integer "today_position"
    t.integer "unassisted_estimate"
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_tasks_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["due_at"], name: "index_tasks_on_due_at"
    t.index ["name"], name: "index_tasks_on_name"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["responsible_user_id", "in_today", "backlog_position"], name: "index_tasks_on_user_backlog_pos"
    t.index ["responsible_user_id", "in_today", "today_position"], name: "index_tasks_on_user_today_pos"
    t.index ["scope_id", "scope_position"], name: "index_tasks_on_scope_pos"
    t.index ["scope_id"], name: "index_tasks_on_scope_id"
    t.index ["state"], name: "index_tasks_on_state"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "name"
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_teams_on_deleted_at", where: "(deleted_at IS NULL)"
    t.index ["name"], name: "index_teams_on_name"
    t.index ["organization_id"], name: "index_teams_on_organization_id"
  end

  create_table "user_party_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "party_id", null: false
    t.string "party_type", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["party_type", "party_id"], name: "index_user_party_roles_on_party"
    t.index ["role"], name: "index_user_party_roles_on_role"
    t.index ["user_id"], name: "index_user_party_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.string "preferred_name"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "uid"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["preferred_name"], name: "index_users_on_preferred_name"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid"], name: "index_users_on_uid", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.index ["username"], name: "index_users_on_username"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.jsonb "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "attachments", "attachables"
  add_foreign_key "attachments", "users"
  add_foreign_key "events", "subscribables"
  add_foreign_key "events", "users"
  add_foreign_key "links", "linkables"
  add_foreign_key "links", "users"
  add_foreign_key "notes", "notables"
  add_foreign_key "notes", "users"
  add_foreign_key "notifications", "events"
  add_foreign_key "notifications", "users"
  add_foreign_key "project_risk_transitions", "projects"
  add_foreign_key "projects", "teams"
  add_foreign_key "report_requirements", "reportables"
  add_foreign_key "report_requirements", "users"
  add_foreign_key "reports", "reportables"
  add_foreign_key "reports", "users"
  add_foreign_key "scopes", "projects"
  add_foreign_key "subscriptions", "subscribables"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "task_transitions", "tasks"
  add_foreign_key "tasks", "projects"
  add_foreign_key "teams", "organizations"
  add_foreign_key "user_party_roles", "users"
end
