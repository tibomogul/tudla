class Attachable < ApplicationRecord
  delegated_type :attachable, types: %w[Project Scope Task Team Organization]

  has_many :attachments, dependent: :destroy
end
