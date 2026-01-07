json.extract! report, :id, :content, :as_of_at, :submitted_at, :reportable_id, :user_id, :created_at, :updated_at
json.url report_url(report, format: :json)
