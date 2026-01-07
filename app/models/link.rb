class Link < ApplicationRecord
  include SoftDeletable
  has_paper_trail
  belongs_to :linkable
  belongs_to :user

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }

  # Broadcasts updates to the links list
  after_commit :broadcast_link_update, on: [ :create, :update, :destroy ]

  # Extract domain from URL for display
  def domain
    return "" if url.blank?

    uri = URI.parse(url)
    uri.host || url
  rescue URI::InvalidURIError
    url
  end

  private

  def broadcast_link_update
    # Broadcast to the parent record's links stream
    return unless linkable&.linkable
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)

    record = linkable.linkable

    broadcast_replace_to(
      "#{record.class.name.underscore}_#{record.id}_links",
      target: "#{record.class.name.underscore}_#{record.id}_links",
      partial: "shared/links_list",
      locals: { links: linkable.links.order(created_at: :desc), show_header: false }
    )
  rescue => e
    Rails.logger.error("Failed to broadcast link update: #{e.message}")
  end
end
