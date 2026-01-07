class Reportable < ApplicationRecord
  delegated_type :reportable, types: %w[Project Team]

  has_many :report_requirements

  has_many :reports
end
