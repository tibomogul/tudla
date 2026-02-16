# frozen_string_literal: true

class AttachmentPreviewCarouselComponent < ViewComponent::Base
  attr_reader :previewable_attachments, :modal_id

  def initialize(attachments:, context_id: nil)
    @previewable_attachments = attachments.select(&:previewable?)
    @modal_id = context_id ? "attachment_preview_carousel_#{context_id}" : "attachment_preview_carousel_modal"
  end

  def render?
    previewable_attachments.any?
  end

  def preview_element_tag(attachment)
    if attachment.image?
      :img
    elsif attachment.pdf?
      :iframe
    elsif attachment.video?
      :video
    elsif attachment.audio?
      :audio
    end
  end
end
