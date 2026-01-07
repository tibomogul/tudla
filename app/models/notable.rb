class Notable < ApplicationRecord
  delegated_type :notable, types: %w[Project Scope Task Team Organization], dependent: :destroy
  has_many :notes, dependent: :destroy
end
