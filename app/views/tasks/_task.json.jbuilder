json.extract! task, :id, :name, :description, :project_id, :scope_id, :created_at, :updated_at
json.url task_url(task, format: :json)
