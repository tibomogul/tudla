class Notable < ApplicationRecord
  delegated_type :notable, types: %w[Project Scope Task Team Organization], dependent: :destroy
  has_many :notes, dependent: :destroy

  # Resolves the underlying delegated record. Tolerant of class-reloading
  # hiccups in development where the delegated_type accessor can momentarily
  # raise; falls back to a manual lookup using the polymorphic columns.
  def resolve_record
    notable
  rescue NameError, ActiveRecord::SubclassNotFound
    notable_type&.constantize&.find_by(id: notable_id)
  end
end
