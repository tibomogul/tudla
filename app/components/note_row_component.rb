# frozen_string_literal: true

class NoteRowComponent < ViewComponent::Base
  attr_reader :note

  def initialize(note:)
    @note = note
  end

  def display_title
    note.title.presence || "Untitled note"
  end

  def edited?
    note.updated_at > note.created_at + 1.minute
  end

  def last_editor
    note.last_editor
  end

  def can_edit?
    helpers.policy(note).edit?
  end

  def can_destroy?
    helpers.policy(note).destroy?
  end
end
