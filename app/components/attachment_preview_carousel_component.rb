# frozen_string_literal: true

class AttachmentPreviewCarouselComponent < ViewComponent::Base
  attr_reader :previewable_attachments

  def initialize(attachments:)
    @previewable_attachments = attachments.select(&:previewable?)
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
