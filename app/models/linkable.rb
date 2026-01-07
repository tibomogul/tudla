class Linkable < ApplicationRecord
  delegated_type :linkable, types: %w[Project Scope Task Team Organization], dependent: :destroy
  has_many :links, dependent: :destroy
end
