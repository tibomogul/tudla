require 'rails_helper'

RSpec.describe AttachmentPreviewCarouselComponent, type: :component do
  include ViewComponent::TestHelpers
  include Capybara::RSpecMatchers
  include Rails.application.routes.url_helpers

  let(:user) { double("User", preferred_name: "Alice", username: "alice") }

  def build_attachment(id:, content_type:, filename: "file.ext", file_size: "1.5 MB")
    double("Attachment",
      id: id,
      filename: filename,
      file_size: file_size,
      content_type: content_type,
      user: user,
      previewable?: %w[image/ video/ audio/ application/pdf].any? { |t| content_type.start_with?(t) },
      image?: content_type.start_with?("image/"),
      pdf?: content_type == "application/pdf",
      video?: content_type.start_with?("video/"),
      audio?: content_type.start_with?("audio/")
    )
  end

  describe "rendering" do
    it "does not render when there are no previewable attachments" do
      zip = build_attachment(id: 1, content_type: "application/zip", filename: "archive.zip")
      result = render_inline(described_class.new(attachments: [ zip ]))
      expect(result.to_html.strip).to be_empty
    end

    it "renders a dialog modal when there are previewable attachments" do
      img = build_attachment(id: 1, content_type: "image/png", filename: "photo.png")
      render_inline(described_class.new(attachments: [ img ]))
      expect(page).to have_css("dialog#attachment_preview_carousel_modal")
    end

    it "renders an img element for image attachments" do
      img = build_attachment(id: 1, content_type: "image/jpeg", filename: "photo.jpg")
      render_inline(described_class.new(attachments: [ img ]))
      expect(page).to have_css('div[data-attachment-preview-target="slide"] img')
    end

    it "renders an iframe element for PDF attachments" do
      pdf = build_attachment(id: 2, content_type: "application/pdf", filename: "doc.pdf")
      render_inline(described_class.new(attachments: [ pdf ]))
      expect(page).to have_css('div[data-attachment-preview-target="slide"] iframe')
    end

    it "renders a video element for video attachments" do
      vid = build_attachment(id: 3, content_type: "video/mp4", filename: "clip.mp4")
      render_inline(described_class.new(attachments: [ vid ]))
      expect(page).to have_css('div[data-attachment-preview-target="slide"] video')
    end

    it "renders an audio element for audio attachments" do
      aud = build_attachment(id: 4, content_type: "audio/mpeg", filename: "song.mp3")
      render_inline(described_class.new(attachments: [ aud ]))
      expect(page).to have_css('div[data-attachment-preview-target="slide"] audio')
    end

    it "excludes non-previewable attachments from slides" do
      img = build_attachment(id: 1, content_type: "image/png", filename: "photo.png")
      zip = build_attachment(id: 2, content_type: "application/zip", filename: "archive.zip")
      render_inline(described_class.new(attachments: [ img, zip ]))
      slides = page.all('div[data-attachment-preview-target="slide"]')
      expect(slides.size).to eq(1)
    end
  end

  describe "carousel navigation" do
    it "renders prev/next buttons when multiple previewable attachments exist" do
      img1 = build_attachment(id: 1, content_type: "image/png", filename: "a.png")
      img2 = build_attachment(id: 2, content_type: "image/jpeg", filename: "b.jpg")
      render_inline(described_class.new(attachments: [ img1, img2 ]))
      expect(page).to have_button("Previous")
      expect(page).to have_button("Next")
    end

    it "does not render prev/next buttons when only one previewable attachment exists" do
      img = build_attachment(id: 1, content_type: "image/png", filename: "solo.png")
      render_inline(described_class.new(attachments: [ img ]))
      expect(page).not_to have_button("Previous")
      expect(page).not_to have_button("Next")
    end
  end

  describe "slide data attributes" do
    it "sets correct data attributes on each slide" do
      img = build_attachment(id: 42, content_type: "image/png", filename: "test.png", file_size: "2.5 MB")
      render_inline(described_class.new(attachments: [ img ]))
      slide = page.find('div[data-attachment-preview-target="slide"]')
      expect(slide[:"data-attachment-id"]).to eq("42")
      expect(slide[:"data-filename"]).to eq("test.png")
      expect(slide[:"data-filesize"]).to eq("2.5 MB")
      expect(slide[:"data-uploader"]).to eq("Alice")
      expect(slide[:"data-preview-type"]).to eq("img")
    end
  end

  describe "stimulus wiring" do
    it "marks the dialog as the attachment-preview dialog target" do
      img = build_attachment(id: 1, content_type: "image/png", filename: "photo.png")
      render_inline(described_class.new(attachments: [ img ]))
      expect(page).to have_css('dialog[data-attachment-preview-target="dialog"]')
    end
  end
end
