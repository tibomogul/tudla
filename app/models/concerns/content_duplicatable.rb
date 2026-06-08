module ContentDuplicatable
  extend ActiveSupport::Concern

  # Copies this record's notes, links, and attachments onto +target+ by value:
  # each yields a brand-new child record owned by the same original author.
  # Soft-deleted children are skipped (.active). Attachments reuse the source
  # blob (independent Attachment rows, deduped storage). All-or-nothing.
  def copy_content_to(target)
    unless target.respond_to?(:notes) && target.respond_to?(:links) && target.respond_to?(:attachments)
      raise ArgumentError, "target must respond to notes/links/attachments"
    end

    transaction do
      copy_notes_to(target)
      copy_links_to(target)
      copy_attachments_to(target)
    end
    target
  end

  private

  def copy_notes_to(target)
    return if notes.active.none?

    notable = Notable.find_or_create_by!(notable_type: target.class.name, notable_id: target.id)
    notes.active.order(:created_at).each do |note|
      notable.notes.create!(
        title: note.title,
        content: note.content,
        user_id: note.user_id,
        last_editor_id: note.last_editor_id
      )
    end
  end

  def copy_links_to(target)
    return if links.active.none?

    linkable = Linkable.find_or_create_by!(linkable_type: target.class.name, linkable_id: target.id)
    links.active.order(:created_at).each do |link|
      linkable.links.create!(url: link.url, description: link.description, user_id: link.user_id)
    end
  end

  def copy_attachments_to(target)
    return if attachments.active.none?

    attachable = Attachable.find_or_create_by!(attachable_type: target.class.name, attachable_id: target.id)
    attachments.active.order(:created_at).each do |attachment|
      next unless attachment.file.attached?

      copy = attachable.attachments.build(description: attachment.description, user_id: attachment.user_id)
      copy.file.attach(attachment.file.blob) # share the immutable blob
      copy.save!
    end
  end
end
