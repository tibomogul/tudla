# Service to handle Slack API interactions for posting reports
class SlackService
  class SlackConfigurationError < StandardError; end
  class SlackPostError < StandardError; end

  # Post a report to Slack based on delivery configuration
  # @param report [Report] The report to post
  # @param report_requirement [ReportRequirement] The report requirement with delivery configuration
  # @return [Boolean] true if posted successfully, false if no Slack configuration
  # @raise [SlackPostError] if posting fails
  def self.post_report(report, report_requirement)
    new(report, report_requirement).post
  end

  def initialize(report, report_requirement)
    @report = report
    @report_requirement = report_requirement

    # Ensure delivery_config is a hash (handle string JSON or nil)
    delivery = report_requirement.delivery
    @delivery_config = case delivery
    when Hash
      delivery
    when String
      JSON.parse(delivery) rescue {}
    else
      {}
    end
  end

  # Check if Slack posting is configured
  def slack_configured?
    @delivery_config.dig("slack", "enabled") == true &&
      (@delivery_config.dig("slack", "webhook_url").present? ||
       @delivery_config.dig("slack", "token").present?)
  end

  # Post the report to Slack
  def post
    return false unless slack_configured?

    if webhook_url.present?
      post_via_webhook
    elsif token.present?
      post_via_api
    else
      false
    end
  end

  private

  def webhook_url
    @delivery_config.dig("slack", "webhook_url")
  end

  def token
    @delivery_config.dig("slack", "token")
  end

  def channel
    @delivery_config.dig("slack", "channel") || "#general"
  end

  def post_via_webhook
    require "net/http"
    require "uri"
    require "json"

    uri = URI.parse(webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    request.body = { text: format_message }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise SlackPostError, "Failed to post to Slack webhook: #{response.code} #{response.message}"
    end

    true
  rescue StandardError => e
    Rails.logger.error("[SlackService] Error posting via webhook: #{e.message}")
    raise SlackPostError, e.message
  end

  def post_via_api
    client = Slack::Web::Client.new(token: token)

    client.chat_postMessage(
      channel: channel,
      text: format_message,
      blocks: format_blocks
    )

    true
  rescue Slack::Web::Api::Errors::SlackError => e
    Rails.logger.error("[SlackService] Slack API error: #{e.message}")
    raise SlackPostError, e.message
  rescue StandardError => e
    Rails.logger.error("[SlackService] Error posting via API: #{e.message}")
    raise SlackPostError, e.message
  end

  def format_message
    reportable_name = @report_requirement.reportable.reportable.try(:name) || "Unknown"
    user_name = @report.user.try(:preferred_name) || @report.user.try(:username) || "Unknown User"
    as_of_date = format_date_in_timezone(@report.as_of_at)

    "*Report: #{reportable_name}*\n" \
    "Submitted by: #{user_name}\n" \
    "As of: #{as_of_date}\n\n" \
    "#{process_emoji(@report.content)}"
  end

  def format_blocks
    reportable_name = @report_requirement.reportable.reportable.try(:name) || "Unknown"
    user_name = @report.user.try(:preferred_name) || @report.user.try(:username) || "Unknown User"
    as_of_date = format_date_in_timezone(@report.as_of_at)

    [
      {
        type: "header",
        text: {
          type: "plain_text",
          text: "📊 #{reportable_name} Report"
        }
      },
      {
        type: "section",
        fields: [
          {
            type: "mrkdwn",
            text: "*Submitted by:*\n#{user_name}"
          },
          {
            type: "mrkdwn",
            text: "*As of:*\n#{as_of_date}"
          }
        ]
      },
      {
        type: "divider"
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: process_emoji(@report.content)
        }
      }
    ]
  end

  # Process emoji replacements for Slack compatibility
  # Converts markdown emoji to their Slack counterparts
  def process_emoji(content)
    return "" if content.blank?

    # Ensure content is a string
    content_str = content.to_s

    content_str
      .gsub(":green_circle:", ":large_green_circle:")
      .gsub(":yellow_circle:", ":large_yellow_circle:")
  end

  # Format date in the organization's timezone
  def format_date_in_timezone(datetime)
    return "Unknown" if datetime.blank?

    organization = get_organization
    timezone = organization&.timezone || "Australia/Brisbane"

    datetime.in_time_zone(timezone).strftime("%B %d, %Y")
  end

  # Get the organization from the reportable (works for Project or Team)
  def get_organization
    reportable = @report_requirement.reportable.reportable
    return nil unless reportable

    case reportable.class.name
    when "Project"
      reportable.team&.organization
    when "Team"
      reportable.organization
    else
      nil
    end
  end
end
